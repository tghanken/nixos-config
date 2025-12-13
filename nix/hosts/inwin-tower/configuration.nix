{
  inputs,
  flake,
  config,
  lib,
  ...
}:
with config; {
  imports = [
    # Standard nixos-anywhere modules
    inputs.disko.nixosModules.disko

    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Add user modules
    flake.modules.users.tghanken

    # Additional NixOs modules from this flake
    flake.nixosModules.bootloader
    flake.nixosModules.bootstrap
    flake.nixosModules.desktop
    flake.nixosModules.kernel
    flake.nixosModules.networking
    flake.nixosModules.secrets
    flake.nixosModules.sound
    flake.nixosModules.tailscale

    flake.modules.desktop.jetbrains
    flake.modules.desktop.ollama
    flake.modules.desktop.steam

    flake.modules.builders.client
    flake.modules.builders.server

    flake.modules.utils.auto-upgrade
    flake.modules.utils.earlyoom
    flake.modules.utils.docker
  ];

  networking.hostName = "inwin-tower"; # Define your hostname.
  networking.hostId = "89cc1717"; # Generate using `head -c 8 /etc/machine-id`

  disko.devices = import ./devices.nix;
  # customBoot.enable = true;
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
