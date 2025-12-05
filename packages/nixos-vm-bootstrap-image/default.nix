{ inputs, ... }:
inputs.nixos-generators.nixosGenerate {
  system = "x86_64-linux";
  modules = [
    ../../hosts/nixos-bootstrap
  ];
  format = "iso";
}
