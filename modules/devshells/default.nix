{inputs, ...}: {
  imports = [
    inputs.devshell.flakeModule
  ];

  perSystem = {
    pkgs,
    inputs',
    ...
  }: {
    devshells.base = {
      commands = [
        {package = pkgs.just;}
      ];
    };

    devshells.default = {
      commands = [
        {package = pkgs.just;}
      ];
      packages = [
        inputs'.agenix.packages.default
        inputs'.nixos-anywhere.packages.default
        inputs'.nix-fast-build.packages.default
      ];
    };
  };
}
