{pkgs, ...}: {
  imports = [
    ./bootloader/bootloader.nix
    ./builders/builders.nix
    ./desktop/desktop.nix
    ./locale/locale.nix
    ./networking/networking.nix
    ./sound/sound.nix
    ./users/users.nix
    ./utils/utils.nix
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.variables.EDITOR = "nano";

  nix.settings = {
    # Reasonable defaults
    connect-timeout = 1;
    download-attempts = 1;
    log-lines = 25;
    max-jobs = "auto";
    min-free = 128000000;
    max-free = 1000000000;
    fallback = true;
    warn-dirty = false;
    keep-outputs = true;

    experimental-features = ["nix-command" "flakes"];
    substituters = [
      "https://nix-community.cachix.org"
      "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };
  # Secrets
  age.secrets = {
    tailscale_key.file = ../secrets/tailscale_key.age;
  };
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
    flake = "/etc/nixos";
  };
  nix.settings.auto-optimise-store = true;
  environment.systemPackages = with pkgs; [
    git
    nano
    curl
  ];
}
