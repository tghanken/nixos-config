{inputs, ...}:
with inputs; let
  home = [
    home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.tghanken = import ./modules/users/tghanken/home-manager.nix;
      };
    }
  ];
  users = [./modules/users/users.nix];

  secrets = [agenix.nixosModules.default ../secrets/mod.nix];

  # Apply to all hosts, including bootstrap images
  bootstrap_mods = [./modules/bootstrap/bootstrap.nix] ++ users;

  # Apply to all hosts, including hosts being adopted
  install_mods = [disko.nixosModules.disko ./modules/install/install.nix] ++ bootstrap_mods;

  # Apply to all activated hosts
  common_mods = [./modules/common/common.nix] ++ install_mods ++ secrets;

  # Apply to only servers
  server_mods = [./modules/server/server.nix] ++ common_mods;

  # Apply to only desktops
  desktop_mods = [./modules/desktop/desktop.nix] ++ common_mods ++ home;
in {
  flake = {
    nixosConfigurations = {
      # Desktops
      inwin-tower = inputs.nixpkgs.lib.nixosSystem {
        modules = [./hosts/desktops/inwin-tower/configuration.nix] ++ desktop_mods;
      };
      nixos-thinkpad = inputs.nixpkgs.lib.nixosSystem {
        modules = [./hosts/desktops/nixos-thinkpad/configuration.nix] ++ desktop_mods;
      };

      # Servers
      nixos-rpi3 = inputs.nixpkgs.lib.nixosSystem {
        modules =
          [
            ./hosts/servers/nixos-rpi3/configuration.nix
            inputs.nixos-hardware.nixosModules.raspberry-pi-3
          ]
          ++ server_mods;
      };
      nixos-rpi4-1 = inputs.nixpkgs.lib.nixosSystem {
        modules =
          [
            ./hosts/servers/nixos-rpi4-1/configuration.nix
            inputs.nixos-hardware.nixosModules.raspberry-pi-4
          ]
          ++ server_mods;
      };
      nixos-rpi4-2 = inputs.nixpkgs.lib.nixosSystem {
        modules =
          [
            ./hosts/servers/nixos-rpi4-2/configuration.nix
            inputs.nixos-hardware.nixosModules.raspberry-pi-4
          ]
          ++ server_mods;
      };
      nixos-rpi4-3 = inputs.nixpkgs.lib.nixosSystem {
        modules =
          [
            ./hosts/servers/nixos-rpi4-3/configuration.nix
            inputs.nixos-hardware.nixosModules.raspberry-pi-4
          ]
          ++ server_mods;
      };
      syno-vm = inputs.nixpkgs.lib.nixosSystem {
        modules = [./hosts/servers/syno-vm/configuration.nix] ++ server_mods;
      };
    };
  };
  perSystem = {
    packages = let
      bootstrap_modules = [./hosts/utils/nixos-bootstrap/configuration.nix] ++ bootstrap_mods;
    in {
      nixos-vm-bootstrap-image = inputs.nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = bootstrap_modules;
        format = "iso";
      };
      # To burn image: sudo zstd -cd ./result/sd-image/{img}.img.zst | sudo dd bs=1M of=/dev/sdX status=progress
      nixos-rpi-bootstrap-image = inputs.nixos-generators.nixosGenerate {
        system = "aarch64-linux";
        modules = bootstrap_modules;
        format = "sd-aarch64";
      };
    };
  };
}
