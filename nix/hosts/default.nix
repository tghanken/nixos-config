{
  self,
  inputs,
  ...
}: let
  lib = inputs.nixpkgs.lib;
  diskoLib = import ../lib/disko.nix {inherit lib;};

  mkHostModules = {
    hostName,
    hostModule,
    hostPubkey ? null,
    users ? ["tghanken"],
    disks ? null,
    diskRole ? null,
    swap ? {},
    ...
  }: let
    facterPath = hostModule + "/facter.json";
    legacyDiskConfig = hostModule + "/disk-config.nix";
    hostPubkeyPath = hostModule + "/key.pub";

    # Host public key for agenix-rekey
    resolvedHostPubkey =
      if hostPubkey != null
      then hostPubkey
      else if builtins.pathExists hostPubkeyPath
      then lib.strings.trim (builtins.readFile hostPubkeyPath)
      else null;

    rekeyModule = lib.optionalAttrs (resolvedHostPubkey != null) {
      age.rekey.hostPubkey = resolvedHostPubkey;
    };

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
      rekeyModule
    ]
    ++ userModules
    ++ [hostModule];

  mkHost = args:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
        inherit (args) hostName;
        flake = self;
        self = self;
      };
      modules = mkHostModules args;
    };

  hosts = {
    hercules = {
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
    pegasus = {
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
    arges = {
      hostName = "arges";
      hostModule = ./arges;
      diskRole = "server-local";
      disks = [
        "/dev/disk/by-id/mmc-TWSC_0x1f41b194"
      ];
    };
    brontes = {
      hostName = "brontes";
      hostModule = ./brontes;
      diskRole = "server-local";
      disks = [
        "/dev/disk/by-id/mmc-TWSC_0x2e43f056"
      ];
    };
    steropes = {
      hostName = "steropes";
      hostModule = ./steropes;
      diskRole = "server-local";
      disks = [
        "/dev/disk/by-id/mmc-TWSC_0x29214bef"
      ];
    };
    hades = {
      hostName = "hades";
      hostModule = ./hades;
      diskRole = "server-remote";
      disks = ["/dev/vda"];
    };
    poseidon = {
      hostName = "poseidon";
      hostModule = ./poseidon;
      diskRole = "server-remote";
      disks = ["/dev/vda"];
    };
    zeus = {
      hostName = "zeus";
      hostModule = ./zeus;
      diskRole = "server-remote";
      disks = ["/dev/vda"];
    };
  };
in {
  flake = {
    nixosConfigurations = lib.mapAttrs (_name: args: mkHost args) hosts;
    colmena = import ./colmena.nix {
      inherit self inputs hosts mkHostModules;
    };
  };
}
