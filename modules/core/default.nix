{...}: {
  imports = [
    ./base.nix
    ./bootloader.nix
    ./determinate.nix
    ./kernel.nix
    ./networking.nix
    ./tailscale.nix
    ./auto-upgrade.nix
    ./earlyoom.nix
    ./headless.nix
    ../features/secrets
  ];
}
