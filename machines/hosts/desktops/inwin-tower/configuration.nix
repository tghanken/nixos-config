# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  pkgs,
  nixpkgs,
  ...
}:
with config; {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Include any additional apps desired
    ../../../modules/desktop/apps/aider.nix
    ../../../modules/desktop/apps/jetbrains.nix
    ../../../modules/desktop/apps/steam.nix
  ];

  networking.hostName = "inwin-tower"; # Define your hostname.
  networking.hostId = "89cc1717"; # Generate using `head -c 8 /etc/machine-id`

  disko.devices = import ./devices.nix;
  customBoot.enable = true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  hardware.graphics = {
    enable = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
