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

  nix.settings.experimental-features = ["nix-command" "flakes"];
  environment.systemPackages = with pkgs; [
    git
    nano
    curl
  ];
}
