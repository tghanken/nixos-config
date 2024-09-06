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
          # Install for the first time with the command:
          # `sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes \
          #   run 'github:nix-community/disko#disko-install' -- \
          #   --flake '.#inwin-tower' --write-efi-boot-entries \
          #   --disk boot /dev/nvme0n1 \
          #   --disk f1 /dev/nvme1n1 \
          #   --disk f2 /dev/nvme2n1 \
          #   --disk bulk1 /dev/sda`
          disko.nixosModules.disko
          {
            disko.devices = import ./machines/inwin-tower/devices.nix;
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
