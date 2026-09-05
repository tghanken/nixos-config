{lib, ...}: {
  /*
  Generates a standardized disko ZFS configuration.

  Arguments:
  - role: "workstation" | "server-local" | "server-remote"
  - disks: list of device strings, e.g. [ "/dev/disk/by-id/..." ]
  - swap: optional swap overrides:
    - encryptedSize: string (e.g. "8G", "10G")
    - zfsEnd: string (e.g. "-58G", "-140G", "-4G")
    - hibernation: bool (default true for workstation)
  */
  mkDiskLayout = {
    role ? "server-local",
    disks,
    swap ? {},
  }: let
    isWorkstation = role == "workstation";
    isServerRemote = role == "server-remote";

    # Swap configuration defaults
    encryptedSwapSize =
      swap.encryptedSize or (
        if isWorkstation
        then "8G"
        else if isServerRemote
        then "4G"
        else null
      );
    zfsPartitionEnd =
      swap.zfsEnd or (
        if isWorkstation
        then "-58G"
        else if isServerRemote
        then "-4G"
        else null
      );
    hasHibernationSwap = isWorkstation && (swap.hibernation or true);

    primaryDiskDevice = builtins.elemAt disks 0;
    secondaryDiskDevices = lib.drop 1 disks;
    hasMultipleDisks = builtins.length disks > 1;

    espSize =
      if isServerRemote
      then "512M"
      else "1G";

    primaryDiskName =
      if hasMultipleDisks
      then "primary"
      else "boot";

    # Primary disk partition definition
    primaryPartitions =
      {
        ESP = {
          size = espSize;
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
          priority = 1;
        };
        zfs =
          {
            priority = 2;
            content = {
              type = "zfs";
              pool = "zroot";
            };
          }
          // (
            if zfsPartitionEnd != null
            then {end = zfsPartitionEnd;}
            else {size = "100%";}
          );
      }
      // lib.optionalAttrs (encryptedSwapSize != null && (isServerRemote || hasHibernationSwap)) {
        encryptedSwap = {
          size =
            if isServerRemote
            then "100%"
            else encryptedSwapSize;
          priority = 100;
          content = {
            type = "swap";
            randomEncryption = true;
            priority = 100;
          };
        };
      }
      // lib.optionalAttrs hasHibernationSwap {
        plainSwap = {
          size = "100%";
          content = {
            type = "swap";
            discardPolicy = "both";
            resumeDevice = true;
          };
        };
      };

    # Primary disk configuration
    primaryDiskConfig = {
      type = "disk";
      device = primaryDiskDevice;
      content = {
        type = "gpt";
        partitions = primaryPartitions;
      };
    };

    # Secondary disks (for striped pools, e.g. hercules)
    namedSecondaryDisks =
      lib.imap1 (
        index: device: let
          name =
            if index == 1
            then "secondary"
            else "disk${toString (index + 1)}";
        in {
          inherit name;
          value = {
            type = "disk";
            inherit device;
            content = {
              type = "gpt";
              partitions = {
                zfs = {
                  size = "100%";
                  priority = 1;
                  content = {
                    type = "zfs";
                    pool = "zroot";
                  };
                };
              };
            };
          };
        }
      )
      secondaryDiskDevices;

    secondaryDiskMap = builtins.listToAttrs namedSecondaryDisks;

    allDisks =
      {
        ${primaryDiskName} = primaryDiskConfig;
      }
      // secondaryDiskMap;

    vdevMembers =
      if hasMultipleDisks
      then ["primary"] ++ (map (d: d.name) namedSecondaryDisks)
      else [primaryDiskName];
  in {
    disk = allDisks;
    zpool = {
      zroot = {
        type = "zpool";
        mode = {
          topology = {
            type = "topology";
            cache = [];
            vdev = [
              {
                members = vdevMembers;
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
  };
}
