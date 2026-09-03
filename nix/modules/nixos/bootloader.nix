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
    autoSnapshot = {
      enable = true;
      frequent = 0; # disable 15-minute snapshots
      hourly = 12; # keep 12 hours
      daily = 7; # keep 7 days
      weekly = 4; # keep 4 weeks
      monthly = 0; # disable 12-month retention
    };
  };
}
