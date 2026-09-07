{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.features.sync;

  currentHost = config.networking.hostName;
  hostsDir = ../hosts;

  # Peer device discovery: checks nix/hosts/<name>/syncthing/id (or legacy nix/hosts/<name>/syncthing.id)
  discoveredDevices = let
    dirEntries = builtins.readDir hostsDir;
    hostDirs = lib.filterAttrs (name: type: type == "directory" && name != currentHost) dirEntries;
    getIdFile = name:
      if builtins.pathExists (hostsDir + "/${name}/syncthing/id")
      then hostsDir + "/${name}/syncthing/id"
      else if builtins.pathExists (hostsDir + "/${name}/syncthing.id")
      then hostsDir + "/${name}/syncthing.id"
      else null;
    hostsWithId = lib.filterAttrs (name: _: getIdFile name != null) hostDirs;
  in
    lib.mapAttrs (name: _: {
      id = lib.strings.trim (builtins.readFile (getIdFile name));
      addresses = ["dynamic" "tcp://${name}:22000"];
    })
    hostsWithId;

  certFile =
    if builtins.pathExists (hostsDir + "/${currentHost}/syncthing/cert.pem")
    then hostsDir + "/${currentHost}/syncthing/cert.pem"
    else hostsDir + "/${currentHost}/syncthing.cert.pem";

  keyAgeFile =
    if builtins.pathExists (hostsDir + "/${currentHost}/syncthing/key.age")
    then hostsDir + "/${currentHost}/syncthing/key.age"
    else hostsDir + "/${currentHost}/syncthing.key.age";

  hasCert = builtins.pathExists certFile;
  hasKey = builtins.pathExists keyAgeFile;
in {
  options.features.sync = {
    enable = mkEnableOption "Cross-host user data synchronization via Syncthing over Tailscale";

    user = mkOption {
      type = types.str;
      default = "tghanken";
      description = "User under which Syncthing service runs.";
    };

    folders = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            path = mkOption {
              type = types.str;
              description = "Absolute path to the synchronized folder.";
            };
            id = mkOption {
              type = types.str;
              description = "Syncthing folder ID shared across nodes.";
            };
            devices = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "List of device names that should sync this folder. If null, automatically shares with all discovered devices.";
            };
            ignorePerms = mkOption {
              type = types.bool;
              default = false;
              description = "Whether to ignore file permissions.";
            };
          };
        }
      );
      default = {};
      description = "Declarative folder registry contributed by features and roles.";
    };

    devices = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            id = mkOption {
              type = types.str;
              default = "";
              description = "Syncthing device ID. Automatically populated if nix/hosts/<name>/syncthing.id exists.";
            };
            addresses = mkOption {
              type = types.listOf types.str;
              default = ["dynamic"];
              description = "Listen/connect addresses for the device.";
            };
          };
        }
      );
      default = discoveredDevices;
      description = "Sync cluster devices. Automatically discovered from nix/hosts/<name>/syncthing.id.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hasCert && hasKey;
        message = ''
          Host '${currentHost}' has features.sync enabled, but Syncthing identity keys are missing!
          Required files:
            - nix/hosts/${currentHost}/syncthing/cert.pem
            - nix/hosts/${currentHost}/syncthing/key.age
            - nix/hosts/${currentHost}/syncthing/id
          Please pregenerate Syncthing identity keys before building:
            just pregenerate-syncthing-keys ${currentHost}   # (or: just psk ${currentHost})
            just rekey-secrets                              # (or: just rs)
        '';
      }
    ];

    # Agenix secret for Syncthing private TLS key
    age.secrets.syncthing_key = mkIf hasKey {
      rekeyFile = keyAgeFile;
      owner = cfg.user;
      group = "users";
      mode = "0600";
    };

    services.syncthing = {
      enable = true;
      inherit (cfg) user;
      dataDir = "/home/${cfg.user}/.local/share/syncthing";
      configDir = "/home/${cfg.user}/.config/syncthing";
      cert = mkIf hasCert "${certFile}";
      key = mkIf hasKey config.age.secrets.syncthing_key.path;
      overrideDevices = false; # allow dynamic UI pairing while supporting declarative config
      overrideFolders = true; # declarative folder synchronization

      settings = {
        devices = lib.filterAttrs (_name: dev: dev.id != "") cfg.devices;
        folders =
          lib.mapAttrs (_name: folder: let
            configuredDeviceNames = builtins.attrNames (lib.filterAttrs (_name: dev: dev.id != "") cfg.devices);
            targetDevices =
              if folder.devices != null
              then builtins.filter (d: cfg.devices ? ${d} && cfg.devices.${d}.id != "") folder.devices
              else configuredDeviceNames;
          in {
            inherit (folder) path id ignorePerms;
            devices = targetDevices;
          })
          cfg.folders;
        gui = {
          enabled = true;
        };
      };
    };

    # Open syncthing transfer ports on Tailscale private interface
    networking.firewall.interfaces."tailscale0" = {
      allowedTCPPorts = [22000 8384]; # 22000: transfer, 8384: Web GUI
      allowedUDPPorts = [22000 21027]; # 22000: transfer, 21027: discovery
    };

    # Persist Syncthing identity keys and index databases across reboots
    environment.persistence."/persist/user".users.${cfg.user}.directories = [
      ".config/syncthing"
      ".local/share/syncthing"
    ];
  };
}
