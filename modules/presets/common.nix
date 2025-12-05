{ inputs, ... }: {
  imports = [
    ../common/common.nix
    ./install.nix
    inputs.agenix.nixosModules.default
    ../../secrets/mod.nix
  ];
}
