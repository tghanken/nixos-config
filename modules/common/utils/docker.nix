{
  lib,
  config,
  ...
}: let
  cfg = config.customBoot;
in {
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = false;
      setSocketVariable = true;
    };
    storageDriver = lib.mkIf cfg.enable "zfs";
    autoPrune = {
      enable = true;
      flags = [];
    };
  };
}
