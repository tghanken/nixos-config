{
  inputs,
  pkgs,
  lib,
  ...
}: let
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "antigravity"
        "antigravity-ide"
      ];
  };
in {
  # System development tooling
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = false;
      setSocketVariable = true;
    };
    storageDriver = "zfs";
    autoPrune = {
      enable = true;
      flags = [];
    };
  };

  programs.nix-ld.enable = true;

  # User development environment for tghanken
  home-manager.users.tghanken = {
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
        "terraform"
        "sql"
      ];
      userSettings = {
        autosave.after_delay.milliseconds = 1000;
        semantic_tokens = "combined";
        project_panel.default_width = 300.0;
        project_panel.dock = "left";
        proxy = "";
        language_models.lmstudio.api_url = "http://localhost:1234/v1";
        cli_default_open_behavior = "new_window";
        agent.profiles = {};
        agent.default_model.provider = "lmstudio";
        agent.default_model.model = "qwen3.8-flash-next";
        agent.default_model.enable_thinking = true;
        agent.favorite_models = [];
        agent.model_parameters = [];
        agent_servers = {
          "pi-acp".type = "registry";
          dirac.default_config_options.mode = "auto";
          dirac.default_config_options.reasoning_effort = "none";
          dirac.type = "registry";
        };
        base_keymap = "VSCode";
        load_direnv = "direct";
        theme = "One Dark";
      };
    };

    programs.direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };

    home.packages = with pkgs;
      [
        unstable.antigravity-ide-fhs
        gh
        nil
        nixd
        # Language servers
        rust-analyzer
        typescript-language-server
        nodejs_22 # required by typescript-language-server
        python3Packages.python-lsp-server
        gopls
      ]
      ++ (with llm-agents; [
        pi
      ]);
  };

  disko.devices.zpool.zroot.datasets = {
    "local/docker" = {
      type = "zfs_fs";
      mountpoint = "/var/lib/docker";
      options."com.sun:auto-snapshot" = "false";
    };
    "local/cargo" = {
      type = "zfs_fs";
      mountpoint = "/home/tghanken/.cargo";
      options."com.sun:auto-snapshot" = "false";
    };
    "local/pnpm" = {
      type = "zfs_fs";
      mountpoint = "/home/tghanken/.local/share/pnpm";
      options."com.sun:auto-snapshot" = "false";
    };
    "local/bun" = {
      type = "zfs_fs";
      mountpoint = "/home/tghanken/.bun";
      options."com.sun:auto-snapshot" = "false";
    };
  };

  environment.persistence."/persist".users.tghanken.directories = [
    ".local/share/direnv"
    ".config/gh"
    ".config/zed"
  ];
}
