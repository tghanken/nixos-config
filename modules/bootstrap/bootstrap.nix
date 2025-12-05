{pkgs, ...}: {
  imports = [
    ./builders/builders.nix
    ./tailscale.nix
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

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
  };
  nix.settings.auto-optimise-store = true;
  environment.systemPackages = with pkgs; [
    git
    nano
    curl
  ];
}
