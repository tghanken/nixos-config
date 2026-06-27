{
  inputs,
  flake,
  ...
}: {
  imports = [
    # Standard nixos-anywhere modules
    inputs.disko.nixosModules.disko
    inputs.nixos-facter-modules.nixosModules.facter
    {
      config.facter.reportPath =
        if builtins.pathExists ./facter.json
        then ./facter.json
        else throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
    }

    # Nixos hardware additions
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series

    # Add user modules
    flake.modules.users.tghanken

    # Add profiles
    flake.modules.profiles.ai
    flake.modules.profiles.development
    flake.modules.profiles.gaming

    # Hermes multi-agent system
    flake.modules.nixos.hermes-multi-agent
  ];

  # Required for nixos-anywhere
  disko.devices = import ./disk-config.nix;
  networking.hostName = "hercules";
  networking.hostId = "c1c4e9e4"; # Generate using `head -c 8 /etc/machine-id`

  system.stateVersion = "25.11"; # initial nixos state

  # Hermes Multi-Agent Configuration
  services.hermes-multi-agent = {
    enable = true;
    lmStudioPort = 1234;
    apiPort = 8642;
    dashboardPort = 9119;
    orchestratorProfile = "orchestrator";
    hostUsers = ["tghanken"];

    # Model configuration
    model.default = "qwen3.6-27b-mtp";

    # External integrations
    # Headroom: Context compression MCP server (60-95% token reduction)
    headroom = {
      enable = true;
      port = 8787;
    };

    # Skills: External agent skills
    skills = {
      installSuperpowers = true;  # SDLC methodology skills
      installPonytail = true;     # Lazy senior dev methodology
    };

    # Secrets for future providers (OpenRouter, Kilo Code Gateway, etc.)
    # Uncomment and configure when ready:
    # secretsFile = config.age.secrets.hermes_api_keys.path;

    # Profiles can be customized here (merged with defaults)
    # profiles = {
    #   # Add custom profiles
    #   researcher = {
    #     enable = true;
    #     description = "Researches topics and writes findings.";
    #     toolsets = ["terminal" "file" "web" "kanban"];
    #   };
    # };
  };
}
