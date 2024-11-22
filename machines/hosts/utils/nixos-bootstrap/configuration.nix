# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
with config; let
  authorizedKeys = [
    # user keys from secrets.nix
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICh921bOnrGEySjw/eRrUAj1UbV2sf1YIcm5X74r6gTh"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOHrxGPx3dgap4sUwWyHbQsMJiv9tSNG05BEMNkNLDZF"
  ];
in {
  networking.hostName = "nixos-bootstrap"; # Define your hostname.
  networking.hostId = "00000000"; # Set placeholder hostid to support zfs

  # Authorize with tailscale as a bootstrap node
  services.tailscale_user.auth_key = "TODO: tskey-auth-placeholder";

  # Enable sshd to generate root keys
  services.openssh = {
    enable = true;
    openFirewall = true;
  };
  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;

  # Enable zfs so disko install works
  boot.supportedFilesystems = ["zfs"];

  # Prebuild install packages
  environment.systemPackages = with pkgs; [
    disko
    zfs
    nix-output-monitor
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
