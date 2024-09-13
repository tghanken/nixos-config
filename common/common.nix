{pkgs, ...}: {
  imports = [
    ./bootloader/bootloader.nix
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
    experimental-features = ["nix-command" "flakes"];
    substituters = [
      "https://nix-community.cachix.org"
      "https://cache.garnix.io"
      "https://cache.nixos.org/"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };
  environment.systemPackages = with pkgs; [
    git
    nano
    curl
  ];
}
