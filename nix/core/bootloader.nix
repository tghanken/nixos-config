{...}: {
  # Setup boot loader
  boot = {
    supportedFilesystems = ["zfs"];
    zfs.devNodes = "/dev/disk/by-partlabel";
    zfs.forceImportRoot = false;
    loader = {
      grub = {
        enable = true;
        # shell_on_fail = true;
        configurationLimit = 10;
        zfsSupport = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        mirroredBoots = [
          {
            devices = ["nodev"];
            path = "/boot";
          }
        ];
      };
    };
  };

  # Enable ZFS services
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };
}
