{
  flake,
  inputs,
  pkgs,
  lib,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "antigravity"
        "code"
        "cursor"
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

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    unstable.antigravity-fhs
    unstable.code-cursor-fhs
    gh
    nil
  ];
}
