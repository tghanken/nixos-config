{
  inputs,
  flake,
  ...
}: let
  system = "x86_64-linux";
  nixos = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = {inherit inputs flake;};
    modules = [
      (
        {modulesPath, ...}: {
          imports = ["${modulesPath}/installer/cd-dvd/iso-image.nix"];
          isoImage.makeEfiBootable = true;
          isoImage.makeUsbBootable = true;
        }
      )
      flake.modules.profiles.bootstrap
      flake.modules.users.tghanken
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
