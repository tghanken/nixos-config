{
  self,
  lib,
  ...
}: {
  perSystem = {
    system,
    config,
    ...
  }: let
    nixosChecks = lib.mapAttrs' (
      name: cfg:
        lib.nameValuePair "nixos-${name}" cfg.config.system.build.toplevel
    ) (lib.filterAttrs (_: cfg: cfg.pkgs.stdenv.hostPlatform.system == system) self.nixosConfigurations);

    pkgChecks =
      lib.mapAttrs' (
        name: pkg:
          lib.nameValuePair "pkgs-${name}" pkg
      )
      config.packages;

    devshellChecks =
      lib.mapAttrs' (
        name: shell:
          lib.nameValuePair "devshell-${name}" shell
      )
      config.devShells;
  in {
    checks = nixosChecks // pkgChecks // devshellChecks;
  };
}
