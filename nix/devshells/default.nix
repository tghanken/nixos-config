{inputs, ...}: {
  imports = [
    inputs.devshell.flakeModule
  ];

  perSystem = {
    pkgs,
    inputs',
    config,
    lib,
    ...
  }: let
    # numtide/devshell exports NIXPKGS_PATH using `toString pkgs.path`, which strips
    # string context and triggers Determinate Nix's "derivation references store path without proper context" warning.
    # See: https://github.com/numtide/devshell/blob/main/modules/env.nix#L136-L141
    # See: https://github.com/DeterminateSystems/nix-src/issues/361
    cleanStartupEnv = {config, ...}: {
      devshell.startup_env = lib.mkForce (
        lib.concatStringsSep "\n" (builtins.filter (e: e.name != "NIXPKGS_PATH") config.env)
      );
    };
  in {
    devshells.base = {
      imports = [cleanStartupEnv];
      commands = [
        {package = pkgs.just;}
      ];
    };

    devshells.default = {
      imports = [cleanStartupEnv];
      commands = [
        {package = pkgs.just;}
      ];
      packages = [
        config.agenix-rekey.package
        inputs'.nixos-anywhere.packages.default
        inputs'.nix-fast-build.packages.default
        pkgs.colmena
        pkgs.rage
        pkgs.age-plugin-yubikey
        pkgs.yubikey-manager
      ];
    };
  };
}
