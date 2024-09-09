# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, modulesPath, ... }:
with config;
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-graphical-base.nix")
  ];
  networking.hostName = "nixos-usb"; # Define your hostname.

  services.tailscale.authKey = "tskey-auth-kUpUwT8ne921CNTRL-xHFfTssLnnZgddFsUiLgqZLxKVSoErMFc";

  # Overrides for graphical base
  boot.loader.grub.enable = lib.mkForce false;
  networking.wireless.enable = lib.mkForce false;
  hardware.pulseaudio.enable = lib.mkForce false;

  # Prebuild disko
  environment.systemPackages = with pkgs; [
    disko
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
