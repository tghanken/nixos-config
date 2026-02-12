{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.netbird_user;

  clientSubmodule = types.submodule ({name, ...}: {
    options = {
      auth_key_path = mkOption {
        type = types.path;
        description = "Netbird auth key file";
      };
      port = mkOption {
        type = types.int;
        default = 51821;
        description = "Wireguard port";
      };
      openFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Open firewall for the port";
      };
      interface = mkOption {
        type = types.str;
        default = "nb-${name}";
        description = "Interface name";
      };
      hardened = mkOption {
        type = types.bool;
        default = false;
        description = "Hardened mode (fails to bring up DNS route)";
      };
    };
  });
in {
  options.services.netbird_user = {
    enable = mkEnableOption "Netbird user service";
    clients = mkOption {
      type = types.attrsOf clientSubmodule;
      default = {};
      description = "Map of Netbird clients";
    };
  };

  config = mkIf cfg.enable {
    # Generate systemd services for each client
    systemd.services =
      mapAttrs' (name: client:
        nameValuePair "netbird-${name}-autoconnect" {
          description = "Automatic connection to Netbird for ${name}";

          # make sure netbird is running before trying to connect
          after = ["network-pre.target" "netbird-${name}.service"];
          wants = ["network-pre.target" "netbird-${name}.service"];
          wantedBy = ["multi-user.target"];

          serviceConfig.Type = "oneshot";

          script = ''
            /run/current-system/sw/bin/netbird-${name} up --setup-key-file ${client.auth_key_path} --allow-server-ssh --enable-ssh-root
          '';
        })
      cfg.clients
      // (
        # protect the secrets in the config file
        mapAttrs' (name: _client:
          nameValuePair "netbird-${name}" {
            serviceConfig.StateDirectoryMode = mkForce "0700";
          })
        cfg.clients
      );

    services.netbird = {
      useRoutingFeatures = "both";
      clients =
        mapAttrs (_name: client: {
          inherit (client) port openFirewall interface hardened;
        })
        cfg.clients;
    };

    # don't delay network-online
    systemd.network.wait-online.ignoredInterfaces = mapAttrsToList (_name: client: client.interface) cfg.clients;

    # make netbird interface trusted
    networking.firewall.trustedInterfaces = mapAttrsToList (_name: client: client.interface) cfg.clients;
  };
}
