{inputs, ...}: {
  imports = [
    {
      config.facter.reportPath =
        if builtins.pathExists ./facter.json
        then ./facter.json
        else throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
    }

    # Hardware additions
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series

    # Role
    ../../roles/workstation.nix

    # Features
    ../../features/ai.nix
    ../../features/development.nix
    ../../features/gaming.nix
    ../../features/github-runner.nix

    # User
    ../../users/tghanken.nix
  ];

  disko.devices = import ./disk-config.nix;
  networking.hostName = "hercules";
  networking.hostId = "c1c4e9e4";

  system.stateVersion = "25.11";

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
