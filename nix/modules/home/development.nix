{
  flake,
  inputs,
  pkgs,
  lib,
  perSystem,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "antigravity"
        "code"
        "vscode"
      ];
  };
in {
  imports = [
    flake.homeModules.desktop
  ];

  programs.vscode = {
    enable = true;
    package = unstable.vscode-fhs;
    profiles = {
      default = {
        enableUpdateCheck = false;
        extensions = with pkgs.vscode-extensions; [
          # Docker
          ms-azuretools.vscode-containers

          # AI assistance
          kilocode.kilo-code
          Google.gemini-cli-vscode-ide-companion

          # Nix development
          jnoortheen.nix-ide

          # Rust development
          rust-lang.rust-analyzer
          tamasfe.even-better-toml

          # Utilities
          gruntfuggly.todo-tree
        ];
        userSettings = {
          "files.autoSave" = "afterDelay";
          "kilo-code.allowedCommands" = [
            "git log"
            "git diff"
            "git show"
            "nix flake check"
          ];
          "kilo-code.deniedCommands" = [];
          "git.enabled" = false;
        };
      };
    };
  };

  programs.gemini-cli = {
    enable = true;
    package = perSystem.nixpkgs-unstable.gemini-cli;
    # Gemini currently struggles to boot when this is set
    # settings = {
    #   "tools" = {
    #     "sandbox" = "docker";
    #   };
    #   "ide" = {
    #     "enabled" = true;
    #     "hasSeenNudge" = true;
    #   };
    #   "security" = {
    #     "auth" = {
    #       "selectedType" = "oauth-personal";
    #     };
    #   };
    #   "general" = {
    #     "previewFeatures" = true;
    #   };
    #   "output" = {
    #     "format" = "text";
    #   };
    #   "ui" = {
    #     "footer" = {
    #       "hideContextPercentage" = false;
    #     };
    #     "showMemoryUsage" = true;
    #     "showModelInfoInChat" = true;
    #   };
    # };
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    unstable.antigravity-fhs
    gh
    nil
  ];
}
