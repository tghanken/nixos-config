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
      self = self;
    };
    modules = [
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
      ../core/base.nix
      ../core/kernel.nix
      ../core/networking.nix
      ../users/tghanken.nix
      {
        networking.hostId = "12345678";
        boot.supportedFilesystems = ["zfs"];
        boot.zfs.forceImportRoot = false;
        system.stateVersion = "25.11";
      }
    ];
  };
in
  nixos.config.system.build.isoImage
