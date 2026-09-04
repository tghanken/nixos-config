{
  self,
  inputs,
  ...
}: let
  lib = inputs.nixpkgs.lib;
  diskoLib = import ../lib/disko.nix {inherit lib;};

  mkHost = {
    hostName,
    hostModule,
    users ? ["tghanken"],
    disks ? null,
    diskRole ? null,
    swap ? {},
  }: let
    facterPath = hostModule + "/facter.json";
    legacyDiskConfig = hostModule + "/disk-config.nix";

    # Disk configuration module
    diskoModule =
      if disks != null
      then {
        disko.devices = diskoLib.mkDiskLayout {
          role =
            if diskRole != null
            then diskRole
            else "server-local";
          inherit disks swap;
        };
      }
      else if builtins.pathExists legacyDiskConfig
      then {
        disko.devices = import legacyDiskConfig;
      }
      else {};

    # User modules
    userModules = map (user: ../users/${user}.nix) users;

    # Automated facter module
    facterModule = lib.optionalAttrs (builtins.pathExists facterPath) {
      config.facter.reportPath = facterPath;
    };

    # Automated hostname
    baseHostModule = {
      networking.hostName = hostName;
    };
  in
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
        inherit hostName;
        flake = self;
        self = self;
      };
      modules =
        [
          inputs.disko.nixosModules.disko
          inputs.nixos-facter-modules.nixosModules.facter
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              flake = self;
              self = self;
            };
          }
          baseHostModule
          facterModule
          diskoModule
        ]
        ++ userModules
        ++ [hostModule];
    };
in {
  flake.nixosConfigurations = {
    hercules = mkHost {
      hostName = "hercules";
      hostModule = ./hercules;
      diskRole = "workstation";
      disks = [
        "/dev/disk/by-id/nvme-WD_BLACK_SN7100_1TB_25360M801190"
        "/dev/disk/by-id/nvme-WD_BLACK_SN7100_1TB_25360M801886"
      ];
      swap = {
        zfsEnd = "-140G";
        encryptedSize = "10G";
      };
    };
    pegasus = mkHost {
      hostName = "pegasus";
      hostModule = ./pegasus;
      diskRole = "workstation";
      disks = [
        "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b42733398"
      ];
      swap = {
        zfsEnd = "-58G";
        encryptedSize = "8G";
      };
    };
    arges = mkHost {
      hostName = "arges";
      hostModule = ./arges;
      diskRole = "server-local";
      disks = [
        "/dev/disk/by-id/mmc-TWSC_0x1f41b194"
      ];
    };
    brontes = mkHost {
      hostName = "brontes";
      hostModule = ./brontes;
      diskRole = "server-local";
      disks = [
        "/dev/disk/by-id/mmc-TWSC_0x2e43f056"
      ];
    };
    steropes = mkHost {
      hostName = "steropes";
      hostModule = ./steropes;
      diskRole = "server-local";
      disks = [
        "/dev/disk/by-id/mmc-TWSC_0x29214bef"
      ];
    };
    hades = mkHost {
      hostName = "hades";
      hostModule = ./hades;
      diskRole = "server-remote";
      disks = ["/dev/vda"];
    };
    poseidon = mkHost {
      hostName = "poseidon";
      hostModule = ./poseidon;
      diskRole = "server-remote";
      disks = ["/dev/vda"];
    };
    zeus = mkHost {
      hostName = "zeus";
      hostModule = ./zeus;
      diskRole = "server-remote";
      disks = ["/dev/vda"];
    };
  };
}
