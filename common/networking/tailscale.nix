{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.tailscale;
in {
  # make the tailscale command usable to users
  config.environment.systemPackages = [pkgs.tailscale];

  # enable the tailscale service
  config.services.tailscale.enable = true;

  # create a oneshot job to authenticate to Tailscale
  config.systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = ["network-pre.target" "tailscale.service"];
    wants = ["network-pre.target" "tailscale.service"];
    wantedBy = ["multi-user.target"];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up -authkey $(cat ${config.age.secrets."tailscale_key".path}) --ssh
    '';
  };
}
