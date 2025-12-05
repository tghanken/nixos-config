{
  lib,
  config,
  ...
}: let
  cfg = config.customBoot;
in {
  config = lib.mkIf cfg.enable {
    services.zfs = {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
    };
  };
}
