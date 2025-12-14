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
    inputs.nixos-hardware.nixosModules.gmktec-nucbox-g3-plus

    # Add user modules
    flake.modules.users.tghanken

    # Additional NixOs modules from this flake
    flake.nixosModules.bootloader
    flake.nixosModules.bootstrap
    flake.nixosModules.kernel
    flake.nixosModules.networking
    flake.nixosModules.tailscale

    flake.modules.secrets.base

    flake.modules.utils.auto-upgrade
    flake.modules.utils.earlyoom
  ];

  # Required for nixos-anywhere
  disko.devices = import ./disk-config.nix;
  networking.hostName = "brontes";
  networking.hostId = "b6ca56e1"; # Generate using `head -c 8 /etc/machine-id`

  system.stateVersion = "25.11"; # initial nixos state
}
