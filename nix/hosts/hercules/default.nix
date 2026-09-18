{inputs, ...}: {
  imports = [
    # Hardware additions
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series

    # Role
    ../../roles/workstation.nix

    # Features
    ../../features/ai.nix
    ../../features/development.nix
    ../../features/gaming.nix

    # Services
    ../../services/github-runner.nix
  ];

  networking.hostId = "c1c4e9e4";
  system.stateVersion = "25.11";

  storage.disks = [
    "/dev/disk/by-id/nvme-WD_BLACK_SN7100_1TB_25360M801190"
    "/dev/disk/by-id/nvme-WD_BLACK_SN7100_1TB_25360M801886"
  ];
  storage.swap = {
    zfsEnd = "-140G";
    encryptedSize = "10G";
  };

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
