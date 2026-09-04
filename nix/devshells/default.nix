{inputs, ...}: {
  imports = [
    inputs.devshell.flakeModule
  ];

  perSystem = {
    pkgs,
    inputs',
    config,
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
        config.agenix-rekey.package
        inputs'.nixos-anywhere.packages.default
        inputs'.nix-fast-build.packages.default
        pkgs.age-plugin-yubikey
        pkgs.yubikey-manager
      ];
    };
  };
}
