{
  inputs,
  self,
  ...
}: {
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = {
    config,
    pkgs,
    lib ? pkgs.lib,
    ...
  }: let
    globalExcludes = [
      "AGENTS.md"
      "pnpm-lock.yaml"
      "**/worker-configuration.d.ts"
    ];
    nixExcludes = [];

    dagPrograms = {
      # Nix
      deadnix = {
        enable = true;
        excludes = nixExcludes;
      };
      nixf-diagnose = {
        enable = true;
      };
      statix = {
        enable = true;
      };
      alejandra = {
        enable = true;
        excludes = nixExcludes;
        after = ["deadnix" "nixf-diagnose" "statix"];
      };

      shfmt = {
        enable = true;
      };
      shellcheck = {
        enable = true;
        after = ["shfmt"];
      };
      taplo = {
        enable = true;
      };
      yamlfmt = {
        enable = true;
      };
      actionlint = {
        enable = true;
      };
      just = {
        enable = true;
      };
    };

    dagCustomFormatters = {};

    allFormatters =
      (lib.mapAttrs (_name: val: val // {_isCustom = false;}) dagPrograms)
      // (lib.mapAttrs (_name: val: val // {_isCustom = true;}) dagCustomFormatters);

    formatterList = lib.mapAttrsToList (name: config: config // {inherit name;}) allFormatters;

    sortedResult = lib.toposort (a: b: lib.elem a.name (b.after or [])) formatterList;

    orderedFormatters =
      if sortedResult ? cycle
      then throw "Cycle detected in treefmt formatters dependencies: ${builtins.toJSON sortedResult.cycle}"
      else sortedResult.result;

    prioritizedFormatters = lib.listToAttrs (lib.imap0 (index: item:
      lib.nameValuePair item.name (
        removeAttrs item ["name" "after" "_isCustom"]
        // {
          priority = index + 1;
        }
      ))
    orderedFormatters);
  in {
    treefmt = {
      projectRootFile = "flake.nix";

      programs = lib.filterAttrs (name: _: !allFormatters.${name}._isCustom) prioritizedFormatters;

      settings = {
        global.excludes = globalExcludes;
        formatter = lib.filterAttrs (name: _: allFormatters.${name}._isCustom) prioritizedFormatters;
      };
    };

    checks.treefmt-check = config.treefmt.build.check self;
  };
}
