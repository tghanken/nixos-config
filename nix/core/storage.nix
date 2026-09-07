{
  lib,
  config,
  ...
}: let
  diskoLib = import ../lib/disko.nix {inherit lib;};
in {
  options.storage = {
    role = lib.mkOption {
      type = lib.types.enum ["workstation" "server-local" "server-remote"];
      default = "server-local";
      description = "Storage role informing Disko partition layout and swap profile.";
    };

    disks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of disk block devices for Disko.";
    };

    swap = {
      encryptedSize = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Size of encrypted swap partition.";
      };

      zfsEnd = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Partition end boundary for ZFS pool partition.";
      };

      hibernation = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to allocate plain swap for hibernation (workstation only).";
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.storage.disks != [] || (config.disko.devices ? disk && config.disko.devices.disk != {});
          message = "storage.disks must be specified (or disko.devices.disk configured) for host '${config.networking.hostName}'";
        }
      ];
    }
    (lib.mkIf (config.storage.disks != []) {
      disko.devices = diskoLib.mkDiskLayout {
        inherit (config.storage) role disks;
        swap = lib.filterAttrs (_: v: v != null) config.storage.swap;
      };
    })
  ];
}
