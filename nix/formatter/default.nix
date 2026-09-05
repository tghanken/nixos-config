{
  inputs,
  self,
  ...
}: {
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = {config, ...}: {
    treefmt = {
      projectRootFile = "flake.nix";
      settings.global.excludes = [];

      programs.deadnix = {
        enable = true;
        priority = 1;
      };
      programs.alejandra = {
        enable = true;
        priority = 2;
      };
      programs.shfmt = {
        enable = true;
        priority = 1;
      };
      programs.shellcheck = {
        enable = true;
        priority = 2;
      };
      programs.taplo = {
        enable = true;
        priority = 2;
      };
      programs.yamlfmt.enable = true;
      programs.actionlint.enable = true;
      programs.just.enable = true;
      programs.nixf-diagnose.enable = true;
    };

    checks.treefmt-check = config.treefmt.build.check self;
  };
}
