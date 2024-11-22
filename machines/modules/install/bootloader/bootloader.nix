{
  lib,
  config,
  ...
}: let
  cfg = config.customBoot;
in {
  options = {
    customBoot.enable = lib.mkEnableOption "Enable Custom Bootloader";
  };

  config = lib.mkIf cfg.enable {
    boot = {
      supportedFilesystems = ["zfs"];
      zfs.devNodes = "/dev/disk/by-partlabel";
      loader = {
        efi = {
          canTouchEfiVariables = true;
        };
        grub = {
          enable = true;
          # shell_on_fail = true;
          configurationLimit = 10;
          zfsSupport = true;
          efiSupport = true;
          mirroredBoots = [
            {
              devices = ["nodev"];
              path = "/boot";
            }
          ];
        };
      };
    };
  };
}
