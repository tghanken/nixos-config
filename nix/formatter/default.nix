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
      "**/.direnv/**"
      "**/result"
      "**/result-*"
      "**/*.age"
    ];
    nixExcludes = [];

    # Formatters grouped by domain / language
    formattersByLanguage = {
      nix = {
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
      };

      shell = {
        shfmt = {
          enable = true;
        };
        shellcheck = {
          enable = true;
          after = ["shfmt"];
        };
      };

      config = {
        taplo = {
          enable = true; # TOML
        };
        yamlfmt = {
          enable = true; # YAML
        };
        actionlint = {
          enable = true; # GitHub Actions Workflow Linter
          after = ["yamlfmt"];
        };
        just = {
          enable = true; # Justfile
        };
      };

      webAndDocs = {
        oxfmt = {
          enable = true; # Markdown, JSON, Web
        };
      };
    };

    # Flatten language groups into master formatters set
    allFormatters = lib.concatMapAttrs (_: v: v) formattersByLanguage;

    isCustomFormatter = f: f ? command || f.isCustom or false;

    formatterList = lib.mapAttrsToList (name: config: config // {inherit name;}) allFormatters;

    sortedResult = lib.toposort (a: b: lib.elem a.name (b.after or [])) formatterList;

    orderedFormatters =
      if sortedResult ? cycle
      then throw "Cycle detected in treefmt formatters dependencies: ${builtins.toJSON sortedResult.cycle}"
      else sortedResult.result;

    prioritizedFormatters = lib.listToAttrs (lib.imap0 (index: item:
      lib.nameValuePair item.name (
        removeAttrs item ["name" "after" "isCustom"]
        // {
          priority = index + 1;
        }
      ))
    orderedFormatters);
  in {
    treefmt = {
      projectRootFile = "flake.nix";

      programs = lib.filterAttrs (_: f: !(isCustomFormatter f)) prioritizedFormatters;

      settings = {
        global.excludes = globalExcludes;
        formatter = lib.filterAttrs (_: isCustomFormatter) prioritizedFormatters;
      };
    };

    checks.treefmt-check = config.treefmt.build.check self;
  };
}
