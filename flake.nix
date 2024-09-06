{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, disko, ... }: {
    nixosConfigurations = {
      inwin-tower = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./machines/inwin-tower/configuration.nix
          ./common/common.nix

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.tghanken = import ./home-manager/home.nix;
          }

          # Setup ZFS drives with disko
          disko.nixosModules.disko
          {
            disko.devices = {
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
                      zfs = {
                        size = "100%";
                        content = {
                          type = "zfs";
                          pool = "zroot";
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
                      # special = {
                      #   members = [ "z" ];
                      # };
                      # cache = [ "cache" ];
                    };
                  };

                  rootFsOptions = {
                    ashift = 12;
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
          }
        ];
      };
      nixos-thinkpad = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./machines/nixos-thinkpad/configuration.nix
          ./common/common.nix

          # make home-manager as a module of nixos
          # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.tghanken = import ./home-manager/home.nix;

            # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
          }
        ];
      };
    };
  };
}
