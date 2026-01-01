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
  ];

  # Required for nixos-anywhere
  disko.devices = import ./disk-config.nix;
  networking.hostName = "hercules";
  networking.hostId = "c1c4e9e4"; # Generate using `head -c 8 /etc/machine-id`

  system.stateVersion = "25.11"; # initial nixos state
}
