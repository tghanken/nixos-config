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

    # GitHub Actions runner container
    flake.modules.utils.github-runner
  ];

  # Required for nixos-anywhere
  disko.devices = import ./disk-config.nix;
  networking.hostName = "hercules";
  networking.hostId = "c1c4e9e4"; # Generate using `head -c 8 /etc/machine-id`

  system.stateVersion = "25.11"; # initial nixos state

  services.github-runner-containers = {
    enable = true;
    runners = [
      {
        owner = "tghanken";
        repo = "nixos-config";
        num = 4;
      }
      {
        owner = "tghanken";
        repo = "seneschal";
        num = 4;
      }
      {
        owner = "actionable-work";
        repo = "actionable";
        num = 4;
      }
    ];
    extraLabels = ["nixos"];
    niks3.uploader.server = "https://niks3-server.actionable-internal.work";
  };
}
