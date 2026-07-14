{
  flake,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  lean-ctx = llm-agents.lean-ctx;
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "antigravity"
        "code"
        "cursor"
        "vscode"
      ];
  };
in
{
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
          "github.copilot.chat.planAgent.additionalTools" = [
            "lean-ctx_ctx_read"
            "lean-ctx_ctx_search"
            "lean-ctx_ctx_tree"
            "lean-ctx_ctx_overview"
            "lean-ctx_ctx_plan"
            "lean-ctx_ctx_metrics"
            "lean-ctx_ctx_compress"
            "lean-ctx_ctx_session"
            "lean-ctx_ctx_knowledge"
            "lean-ctx_ctx_graph"
            "lean-ctx_ctx_retrieve"
            "lean-ctx_ctx_provider"
          ];
          "kilo-code.allowedCommands" = [
            "git log"
            "git diff"
            "git show"
            "nix flake check"
          ];
          "kilo-code.deniedCommands" = [ ];
          "chat.mcp.enabled" = true;
          "git.enabled" = false;
        };
      };
    };
  };

  programs.zed-editor = {
    enable = true;
    package = unstable.zed-editor;
    extensions = [
      "nix"
      "toml"
      "rust"
      "dockerfile"
      "markdown"
      "svelte"
      "vue"
      "astro"
      "html"
      "css"
    ];
    userSettings = {
      theme = {
        mode = "system";
        dark = "One Dark";
        light = "One Light";
      };
      load_direnv = "shell_hook";
    };
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs;
    [
      unstable.antigravity-fhs
      unstable.code-cursor-fhs
      gh
      nil
      nixd
    ]
    ++ (with llm-agents; [
      pi
      lean-ctx
    ]);

  home.file = {
    ".pi/agent/extensions/pi-lean-ctx/config.json" = {
      text = builtins.toJSON {
        mode = "replace";
        enableMcp = true;
        toolProfile = "power";
        binary = "${lean-ctx}/bin/lean-ctx";
      };
    };
  };
}
