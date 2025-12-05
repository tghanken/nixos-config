# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  inputs,
  ...
}:
with config; {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/hardware/raspberry-pi/pi4.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-4

    # Presets
    ../../modules/presets/server.nix
  ];

  networking.hostName = "nixos-rpi4-2"; # Define your hostname.
  networking.hostId = "b8c9164e"; # Generate using `head -c 8 /etc/machine-id`

  boot.binfmt.emulatedSystems = ["x86_64-linux"];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
