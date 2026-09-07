{inputs, ...}: {
  imports = [
    # Hardware additions
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series

    # Role
    ../../roles/workstation.nix

    # Features
    ../../features/development.nix
    ../../features/gaming.nix
  ];

  networking.hostId = "8561a55b";
  system.stateVersion = "25.11";

  storage.disks = [
    "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b42733398"
  ];
  storage.swap = {
    zfsEnd = "-58G";
    encryptedSize = "8G";
  };
}
