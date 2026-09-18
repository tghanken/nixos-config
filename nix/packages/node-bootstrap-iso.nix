{
  inputs,
  self,
  ...
}: let
  system = "x86_64-linux";
  nixos = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs;
      flake = self;
      inherit self;
    };
    modules = [
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit inputs;
          flake = self;
          inherit self;
        };
      }
      (
        {modulesPath, ...}: {
          imports = [
            "${modulesPath}/installer/cd-dvd/iso-image.nix"
            "${modulesPath}/installer/scan/not-detected.nix"
          ];
          isoImage.makeEfiBootable = true;
          isoImage.makeUsbBootable = true;
        }
      )
      ../core/system.nix
      ../users/tghanken.nix
      {
        networking.hostId = "12345678";
        boot.supportedFilesystems = ["zfs"];
        boot.zfs.forceImportRoot = false;
        boot.loader.grub.enable = false;
        system.autoUpgrade.enable = false;
        system.stateVersion = "25.11";
      }
      {
        options.environment.persistence = inputs.nixpkgs.lib.mkOption {
          type = inputs.nixpkgs.lib.types.attrsOf inputs.nixpkgs.lib.types.anything;
          default = {};
        };
      }
    ];
  };
in
  nixos.config.system.build.isoImage
