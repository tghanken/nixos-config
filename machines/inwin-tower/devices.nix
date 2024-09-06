{
  disk = {
    boot = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "64M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          zroot = {
            end = "-32G";
            content = {
              type = "zfs";
              pool = "zroot";
            };
          };
          encryptedSwap = {
            size = "1G";
            content = {
              type = "swap";
              randomEncryption = true;
              priority = 100; # prefer to encrypt as long as we have space for it
            }
          };
          plainSwap = {
            size = "100%";
            content = {
              type = "swap";
              discardPolicy = "both";
              resumeDevice = true; # resume from hibernation from this device
            }
          }
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
    backup = {
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
          vdev = [
            {
              # mode = "mirror";
              members = [ "boot" ];
            }
          ];
        };
      };

      rootFsOptions = {
        ashift = "12";
        xattr = "sa";
        compression = "lz4";
        atime = "off";
        recordsize = "64K";
      };
      mountpoint = "/";
      datasets = {
        # See examples/zfs.nix for more comprehensive usage.
        root = {
          type = "zfs_fs";
          mountpoint = "/zfs_fs";
          options."com.sun:auto-snapshot" = "true";
        };
        nix = {

        };
        var = {

        };
        home = {

        };
      };
    };
  };
};
