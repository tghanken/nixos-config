{...}: {
  imports = [
    ./system.nix
    ./headless.nix
    ./tailscale.nix
    ../features/secrets
  ];
}
