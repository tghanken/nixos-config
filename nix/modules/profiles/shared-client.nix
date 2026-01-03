{
  flake,
  config,
  ...
}:
with config; {
  imports = [
    flake.modules.profiles.shared-all

    flake.nixosModules.sound
  ];

  # age.secrets.netbird_key.file = ../secrets/secret_files/encrypted/netbird_taylor_client.age;
  # services.netbird_user.auth_key_path = age.secrets.netbird_key.path;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Cinnamon Desktop Environment.
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
}
