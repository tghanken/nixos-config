{
  imports = [
    ./firewall.nix
    ./tailscale.nix
  ];

  # Enable networking
  networking.networkmanager.enable = true;
}