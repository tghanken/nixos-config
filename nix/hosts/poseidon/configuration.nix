{
  inputs,
  flake,
  modulesPath,
  ...
}: {
  imports = [
    # QEMU Guest for virtualized host
    (modulesPath + "/profiles/qemu-guest.nix")

    # Standard nixos-anywhere modules
    inputs.disko.nixosModules.disko
    inputs.nixos-facter-modules.nixosModules.facter
    {
      config.facter.reportPath =
        if builtins.pathExists ./facter.json
        then ./facter.json
        else throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
    }

    # Add user modules
    flake.modules.users.tghanken

    # Add profiles
    flake.modules.profiles.remote-server
  ];

  # Required for nixos-anywhere
  disko.devices = import ./disk-config.nix;
  networking.hostName = "poseidon";
  networking.hostId = "b9f3a8fc"; # Generate using `head -c 8 /etc/machine-id`

  system.stateVersion = "25.11"; # initial nixos state
}
