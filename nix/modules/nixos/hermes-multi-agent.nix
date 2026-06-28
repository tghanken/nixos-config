# Hermes Multi-Agent System
#
# Sets up a single Hermes Agent container with multiple profiles for
# coordinated multi-agent work via the Kanban system.
#
# Profiles:
#   - orchestrator: User-facing coordinator (kanban + gateway tools only)
#   - planner: Breaks requests into technical specs
#   - builder: Implements code from specs
#   - reviewer: Reviews code for quality and correctness
#
# All profiles share the same container, kanban.db, and LM Studio connection.
# The dispatcher auto-decomposes tasks and routes them to the right profiles.
#
# External integrations:
#   - headroom: Context compression MCP server (60-95% token reduction)
#   - superpowers: SDLC methodology skills (brainstorming, TDD, code review)
#   - ponytail: Lazy senior dev methodology (YAGNI, minimal code, audit)

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.services.hermes-multi-agent;

  # Custom Docker image for the terminal backend sandbox with Determinate Nix
  # This image extends nikolaik/python-nodejs with nix installed via Determinate Systems
  terminalSandboxImage = pkgs.callPackage ../../packages/hermes-terminal-sandbox.nix { };

  # Soul files for each profile
  souls = {
    orchestrator = ./hermes-souls/orchestrator.md;
    planner = ./hermes-souls/planner.md;
    builder = ./hermes-souls/builder.md;
    reviewer = ./hermes-souls/reviewer.md;
  };

  # Default profile definitions
  defaultProfiles = {
    orchestrator = {
      description = "User-facing coordinator. Decomposes requests, delegates to specialists, collects and judges results.";
      toolsets = ["kanban" "gateway" "memory"];
    };
    planner = {
      description = "Breaks feature requests into detailed technical specs with acceptance criteria, architecture decisions, and implementation steps.";
      toolsets = ["terminal" "file" "web" "kanban"];
    };
    builder = {
      description = "Implements code from specs. Writes, tests, and commits code changes. Works in git worktrees.";
      toolsets = ["terminal" "file" "kanban" "mcp"];
    };
    reviewer = {
      description = "Reviews code for correctness, security, style, edge cases, and test coverage. Blocks tasks that need fixes.";
      toolsets = ["terminal" "file" "kanban" "mcp"];
    };
  };

  # Merge user-provided profiles with defaults
  mergedProfiles = lib.recursiveUpdate defaultProfiles cfg.profiles;

  # Filter to only enabled profiles
  enabledProfiles = builtins.filterAttrs (_: v: v.enable) mergedProfiles;

  # Profile names list
  profileNames = builtins.attrNames enabledProfiles;

  # Generate profile creation commands
  profileCreateCmds = builtins.map (name:
    let
      p = enabledProfiles.${name};
    in
    "hermes profile create ${name} --description \"${p.description}\""
  ) profileNames;

  # Generate SOUL.md copy commands
  soulCopyCmds = builtins.map (name:
    let
      soulPath = souls.${name} or null;
    in
    if soulPath != null
    then "cp ${soulPath} ${config.services.hermes-agent.home}/profiles/${name}/SOUL.md"
    else ""
  ) profileNames;

  # Filter out empty strings
  nonEmptySoulCmds = builtins.filter (s: s != "") soulCopyCmds;

  # Skills installation script
  # Clones external skills from GitHub into the shared skills directory
  skillsInstallScript = ''
    echo "Installing external skills..."
    SKILLS_DIR="${config.services.hermes-agent.home}/skills"
    mkdir -p "$SKILLS_DIR"

    ${lib.optionalString cfg.skills.installSuperpowers ''
      # Superpowers skills
      TEMP_SUPERPOWERS=$(mktemp -d)
      git clone --depth 1 https://github.com/obra/superpowers "$TEMP_SUPERPOWERS"
      if [ -d "$TEMP_SUPERPOWERS/skills" ]; then
        cp -r "$TEMP_SUPERPOWERS/skills"/* "$SKILLS_DIR/" 2>/dev/null || true
        echo "  Installed superpowers skills"
      fi
      rm -rf "$TEMP_SUPERPOWERS"
    ''}

    ${lib.optionalString cfg.skills.installPonytail ''
      # Ponytail skills
      TEMP_PONYTAIL=$(mktemp -d)
      git clone --depth 1 https://github.com/DietrichGebert/ponytail "$TEMP_PONYTAIL"
      if [ -d "$TEMP_PONYTAIL/skills" ]; then
        cp -r "$TEMP_PONYTAIL/skills"/* "$SKILLS_DIR/" 2>/dev/null || true
        echo "  Installed ponytail skills"
      fi
      rm -rf "$TEMP_PONYTAIL"
    ''}
  '';

  # Headroom MCP server configuration
  # headroom provides context compression (60-95% token reduction)
  # It runs as an MCP server inside the container
  # config.yaml key is mcp_servers (snake_case)
  headroomMcpServers = lib.optionalAttrs cfg.headroom.enable {
    headroom = {
      command = "headroom";
      args = ["mcp"];
    };
  };
in {
  options.services.hermes-multi-agent = {
    enable = lib.mkEnableOption "Hermes multi-agent system";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.hermes-agent.packages.${pkgs.system}.default;
      description = "Hermes Agent package to use";
    };

    lmStudioPort = lib.mkOption {
      type = lib.types.port;
      default = 1234;
      description = "Host port where LM Studio is running";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 8642;
      description = "Host port to expose the Hermes API server on";
    };

    dashboardPort = lib.mkOption {
      type = lib.types.port;
      default = 9119;
      description = "Host port to expose the Hermes dashboard on";
    };

    orchestratorProfile = lib.mkOption {
      type = lib.types.str;
      default = "orchestrator";
      description = "Profile assigned to root/orchestration tasks";
    };

    hostUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Host users with CLI access to the Hermes container";
    };

    extraVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional container volume mounts";
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to env file with API keys (for OpenRouter, etc.)";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "This profile" // {default = true;};
          description = lib.mkOption {
            type = lib.types.str;
            description = "Profile description used by the kanban decomposer for routing";
          };
          toolsets = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Toolsets available to this profile";
          };
        };
      });
      default = {};
      description = "Profile definitions (merged with defaults)";
    };

    model = lib.mkOption {
      type = lib.types.submodule {
        options = {
          default = lib.mkOption {
            type = lib.types.str;
            default = "qwen3.6-27b-mtp";
            description = "Default model to use (LM Studio model ID)";
          };
        };
      };
      default = {};
      description = "Model configuration";
    };

    # External integrations
    headroom = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Headroom context compression MCP server" // {default = true;};
          port = lib.mkOption {
            type = lib.types.port;
            default = 8787;
            description = "Port for headroom proxy (if using proxy mode)";
          };
        };
      };
      default = {};
      description = "Headroom context compression configuration";
    };

    skills = lib.mkOption {
      type = lib.types.submodule {
        options = {
          installSuperpowers = lib.mkEnableOption "Install superpowers skills" // {default = true;};
          installPonytail = lib.mkEnableOption "Install ponytail skills" // {default = true;};
        };
      };
      default = {};
      description = "External skills installation configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Docker (required for container mode)
    imports = [
      inputs.hermes-agent.nixosModules.default
    ];

    virtualisation.docker.enable = true;

    # Main Hermes service configuration
    services.hermes-agent = {
      enable = true;
      package = cfg.package;

      # Container mode
      container = {
        enable = true;
        hostUsers = cfg.hostUsers;
        extraVolumes = cfg.extraVolumes;
        # Forward ports from host into container
        forwardPorts = [
          {
            hostPort = cfg.lmStudioPort;
            containerPort = 1234;
            protocol = "tcp";
          }
          {
            hostPort = cfg.apiPort;
            containerPort = 8642;
            protocol = "tcp";
          }
          {
            hostPort = cfg.dashboardPort;
            containerPort = 9119;
            protocol = "tcp";
          }
          # Headroom proxy port (if enabled)
          (lib.mkIf cfg.headroom.enable {
            hostPort = cfg.headroom.port;
            containerPort = cfg.headroom.port;
            protocol = "tcp";
          })
        ];
      };

      # Add CLI to system PATH with container routing
      addToSystemPackages = true;

      # Model configuration (LM Studio via forwarded port)
      settings = {
        model = {
          base_url = "http://localhost:1234/v1";
          default = cfg.model.default;
        };

        # Terminal backend: Docker sandbox with Determinate Nix
        terminal = {
          backend = "docker";
          docker_image = "hermes-terminal-sandbox:latest";
        };

        # Kanban configuration
        kanban = {
          auto_decompose = true;
          orchestrator_profile = cfg.orchestratorProfile;
          dispatch_in_gateway = true;
          dispatch_interval_seconds = 60;
          # Use worktrees for builder tasks
          default_workspace_kind = "worktree";
          # Enable goal mode for iterative work
          goal_mode = true;
          goal_max_turns = 20;
        };

        # Compression for efficiency
        compression = {
          enabled = true;
          threshold = 0.85;
        };

        # Memory
        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
        };

        # MCP servers (config.yaml: mcp_servers)
        mcp_servers = headroomMcpServers;
      };

      # Secrets (optional)
      environmentFiles = lib.optional (cfg.secretsFile != null) cfg.secretsFile;

      # Service tuning
      restart = "always";
      restartSec = 5;
    };

    # Profile initialization service
    # Runs once to create profiles, install skills, and initialize kanban
    systemd.services."hermes-init-profiles" = {
      description = "Initialize Hermes multi-agent profiles";
      # Run after the container is up but before we expect the gateway to handle requests
      after = ["hermes-agent.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "hermes";
        Group = "hermes";
        WorkingDirectory = config.services.hermes-agent.home;
      };
      script = ''
        # Guard: only run once
        if [ -f ${config.services.hermes-agent.home}/.profiles-initialized ]; then
          exit 0
        fi

        echo "Initializing Hermes profiles..."

        # Wait for the container to be ready
        sleep 10

        # Create profiles
        ${lib.concatStringsSep "\n" profileCreateCmds}

        # Copy SOUL.md files
        ${lib.concatStringsSep "\n" nonEmptySoulCmds}

        # Install external skills
        ${skillsInstallScript}

        # Install headroom (context compression)
        ${lib.optionalString cfg.headroom.enable ''
          echo "Installing headroom..."
          pip install "headroom-ai[all]" --break-system-packages 2>/dev/null || pip install "headroom-ai[all]"
          echo "  headroom installed"
        ''}

        # Initialize kanban board
        hermes kanban init

        # Configure API server via environment
        echo "API_SERVER_ENABLED=true" >> ${config.services.hermes-agent.home}/.env
        echo "API_SERVER_KEY=hermes-local-dev-key" >> ${config.services.hermes-agent.home}/.env

        # Mark as initialized
        touch ${config.services.hermes-agent.home}/.profiles-initialized

        echo "Hermes profiles initialized successfully"
      '';
    };

    # Load the custom terminal sandbox Docker image into Docker
    # This runs on boot and after the image derivation changes
    systemd.services."load-hermes-terminal-sandbox" = {
      description = "Load Hermes terminal sandbox Docker image";
      after = ["docker.service"];
      requires = ["docker.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        echo "Loading hermes-terminal-sandbox Docker image..."
        docker load -i ${terminalSandboxImage}
        echo "Image loaded successfully"
      '';
    };
  };
}
