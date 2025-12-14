{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.netbird_user;
  null_path = /dev/null;
in {
  options.services.netbird_user = {
    auth_key_path = mkOption {
      type = types.path;
      description = "Netbird auth key file";
      default = null_path;
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.auth_key_path != null_path;
        message = "`auth_key_path` must be set";
      }
    ];

    # create a oneshot job to authenticate to Netbird
    systemd.services.netbird-autoconnect = {
      description = "Automatic connection to Netbird";

      # make sure netbird is running before trying to connect to netbird
      after = ["network-pre.target" "netbird-default.service"];
      wants = ["network-pre.target" "netbird-default.service"];
      wantedBy = ["multi-user.target"];

      # set this service as a oneshot job
      serviceConfig.Type = "oneshot";

      script = with pkgs; ''
        /run/current-system/sw/bin/netbird-default up --setup-key-file ${cfg.auth_key_path} --allow-server-ssh --enable-ssh-root
      '';
    };

    services.netbird = {
      useRoutingFeatures = "both";
      clients.default = {
        # default wireguard port 51820 for k3s flannel-wg
        port = 51821;
        openFirewall = true;
        interface = "netbird";
        hardened = false; # fails to bring up DNS route
      };
    };

    # don't delay network-online
    systemd.network.wait-online.ignoredInterfaces = [config.services.netbird.clients.default.interface];

    # protect the secrets in the config file
    systemd.services.netbird-default.serviceConfig.StateDirectoryMode = mkForce "0700";
  };
}
