{perSystem, ...}:
perSystem.devshell.mkShell {
  imports = [(perSystem.devshell.importTOML ./devshells/base.toml)];
  devshell.packages = [
    perSystem.agenix.default
    perSystem.nixos-anywhere.default
    perSystem.nix-fast-build.default
  ];
}
