{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.features.sync;

  currentHost = config.networking.hostName;
  hostsDir = ../hosts;

  # Auto-discover all peer host directories in nix/hosts/ that contain a syncthing.id file
  discoveredDevices = let
    dirEntries = builtins.readDir hostsDir;
    hostDirs = lib.filterAttrs (name: type: type == "directory" && name != currentHost) dirEntries;
    hostsWithId = lib.filterAttrs (name: _: builtins.pathExists (hostsDir + "/${name}/syncthing.id")) hostDirs;
  in
    lib.mapAttrs (name: _: {
      id = lib.strings.trim (builtins.readFile (hostsDir + "/${name}/syncthing.id"));
      addresses = ["dynamic" "tcp://${name}:22000"];
    })
    hostsWithId;
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
    services.syncthing = {
      enable = true;
      inherit (cfg) user;
      dataDir = "/home/${cfg.user}/.local/share/syncthing";
      configDir = "/home/${cfg.user}/.config/syncthing";
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
