{
  disk = {
    boot = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          MBR = {
            type = "EF02";
            size = "1M";
            priority = 1;
          };
          ESP = {
            size = "64M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
            priority = 2;
          };
          zfs = {
            end = "-32G";
            content = {
              type = "zfs";
              pool = "zroot";
            };
            priority = 3;
          };
          encryptedSwap = {
            size = "1G";
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
    f1 = {
      type = "disk";
      device = "/dev/nvme1n1";
      content = {
        type = "gpt";
        partitions = {
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "zflash";
            };
          };
        };
      };
    };
    f2 = {
      type = "disk";
      device = "/dev/nvme2n1";
      content = {
        type = "gpt";
        partitions = {
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "zflash";
            };
          };
        };
      };
    };
    bulk1 = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "zbulk";
            };
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
              members = [ "boot" ];
            }
          ];
        };
      };
      rootFsOptions = {
        # ashift = "12";
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
    zflash = {
      type = "zpool";
      mode = {
        topology = {
          type = "topology";
          cache = [];
          vdev = [
            {
              members = [ "f1" "f2" ];
            }
          ];
        };
      };
      rootFsOptions = {
        # ashift = "12";
        xattr = "sa";
        compression = "lz4";
        atime = "off";
        recordsize = "64K";
        "com.sun:auto-snapshot" = "true";
      };
      datasets = {
        steam = {
          type = "zfs_fs";
          mountpoint = "/mnt/steam";
        };
        reserved = {
          type = "zfs_fs";
          options.refreservation = "10G";
          options.mountpoint = "none";
        };
      };
    };
    zbulk = {
      type = "zpool";
      mode = {
        topology = {
          type = "topology";
          cache = [];
          vdev = [
            {
              members = [ "bulk1" ];
            }
          ];
        };
      };
      rootFsOptions = {
        # ashift = "12";
        xattr = "sa";
        compression = "lz4";
        atime = "off";
        recordsize = "64K";
        "com.sun:auto-snapshot" = "true";
      };
      datasets = {
        hyper-backup = {
          type = "zfs_fs";
          mountpoint = "/mnt/hyper-backup";
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