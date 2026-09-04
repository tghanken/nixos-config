{inputs, ...}: {
  imports = [
    {
      config.facter.reportPath =
        if builtins.pathExists ./facter.json
        then ./facter.json
        else throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
    }

    # Hardware additions
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series

    # Role
    ../../roles/workstation.nix

    # Features
    ../../features/development.nix
    ../../features/gaming.nix

    # User
    ../../users/tghanken.nix
  ];

  disko.devices = import ./disk-config.nix;
  networking.hostName = "pegasus";
  networking.hostId = "8561a55b";

  system.stateVersion = "25.11";
}
