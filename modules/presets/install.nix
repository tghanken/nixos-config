{ inputs, ... }: {
  imports = [
    inputs.disko.nixosModules.disko
    ../install/install.nix
    ./bootstrap.nix
  ];
}
