{
  self,
  lib,
  ...
}: {
  perSystem = {
    system,
    config,
    pkgs,
    ...
  }: let
    diskoLib = import ../lib/disko.nix {inherit lib;};

    nixosChecks = lib.mapAttrs' (
      name: cfg:
        lib.nameValuePair "nixos-${name}" cfg.config.system.build.toplevel
    ) (lib.filterAttrs (_: cfg: cfg.pkgs.stdenv.hostPlatform.system == system) self.nixosConfigurations);

    diskLayoutChecks = lib.mapAttrs' (
      name: cfg: let
        layoutFile = ../hosts + "/${name}/disk-layout.json";
        actual = diskoLib.sanitizeDiskoDevices cfg.config.disko.devices;
        expected =
          if builtins.pathExists layoutFile
          then builtins.fromJSON (builtins.readFile layoutFile)
          else null;
        isMatch = expected != null && actual == expected;
      in
        lib.nameValuePair "disk-layout-${name}" (
          if isMatch
          then
            pkgs.runCommand "check-disk-layout-${name}" {} ''
              echo "Disk layout contract for ${name} verified."
              touch $out
            ''
          else
            pkgs.runCommand "check-disk-layout-${name}-mismatch" {} ''
              echo "ERROR: Disk layout for ${name} does not match nix/hosts/${name}/disk-layout.json!" >&2
              echo "Run 'just update-disk-layouts' if this change was intentional." >&2
              exit 1
            ''
        )
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
    checks = nixosChecks // diskLayoutChecks // pkgChecks // devshellChecks;
  };
}
