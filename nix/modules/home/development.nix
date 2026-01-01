{
  flake,
  pkgs,
  ...
}: {
  imports = [
    flake.homeModules.desktop
  ];

  programs.vscode = {
    enable = true;
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
        };
      };
    };
  };

  programs.gemini-cli.enable = true;

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    antigravity
    gh
  ];
}
