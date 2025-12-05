{ inputs, ... }:
inputs.nixos-generators.nixosGenerate {
  system = "aarch64-linux";
  modules = [
    ../../hosts/nixos-bootstrap
  ];
  format = "sd-aarch64";
}
