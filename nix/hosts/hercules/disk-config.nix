{
  disk = {
    primary = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-WD_BLACK_SN7100_1TB_25360M801190";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
            priority = 1;
          };
          zfs = {
            end = "-140G";
            content = {
              type = "zfs";
              pool = "zroot";
            };
            priority = 2;
          };
          encryptedSwap = {
            size = "10G";
            content = {
              type = "swap";
              randomEncryption = true;
              priority = 100; # prefer to encrypt as long as we have space for it
            };
          };
          plainSwap = {
            size = "100%";
            content = {
              type = "swap";
              discardPolicy = "both";
              resumeDevice = true; # resume from hibernation from this device
            };
          };
        };
      };
    };
    secondary = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-WD_BLACK_SN7100_1TB_25360M801886";
      content = {
        type = "gpt";
        partitions = {
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "zroot";
            };
            priority = 1;
          };
        };
      };
    };
  };
  zpool = {
    zroot = {
      type = "zpool";
      mode = {
        topology = {
          type = "topology";
          cache = [];
          vdev = [
            {
              members = ["primary" "secondary"];
            }
          ];
        };
      };
      rootFsOptions = {
        xattr = "sa";
        compression = "lz4";
        atime = "off";
        recordsize = "64K";
        "com.sun:auto-snapshot" = "true";
      };
      mountpoint = "/";
      datasets = {
        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options."com.sun:auto-snapshot" = "false";
        };
        var = {
          type = "zfs_fs";
          mountpoint = "/var";
        };
        home = {
          type = "zfs_fs";
          mountpoint = "/home";
        };
        reserved = {
          type = "zfs_fs";
          options.refreservation = "10G";
          options.mountpoint = "none";
        };
      };
    };
  };
}
