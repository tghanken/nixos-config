# Development shell for the NixOS configuration
{
  pkgs,
  inputs,
  system,
  ...
}: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      inputs.agenix.packages.${system}.default
    ];
  };
}
