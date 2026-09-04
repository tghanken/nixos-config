{...}: {
  imports = [
    ./system.nix
    ./headless.nix
    ./tailscale.nix
    ./secrets
  ];
}
