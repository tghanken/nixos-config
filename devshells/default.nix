{ pkgs, inputs, system, ... }:
pkgs.mkShell {
  packages = with pkgs; [
    inputs.agenix.packages.${system}.default
  ];
}
