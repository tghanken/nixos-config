{
  flake,
  config,
  pkgs,
  ...
}:
with config; {
  imports = [
    flake.modules.profiles.shared-all

    flake.nixosModules.sound
    flake.nixosModules.netbird
  ];

  age.secrets.netbird_taylor_client.file = ../secrets/secret_files/encrypted/netbird_taylor_client.age;
  age.secrets.netbird_actionable_tghanken_client.file = ../secrets/secret_files/encrypted/netbird_actionable_tghanken_client.age;
  services.netbird_user = {
    enable = true;
    clients = {
      default = {
        auth_key_path = age.secrets.netbird_taylor_client.path;
        port = 51821;
        openFirewall = true;
        hardened = false;
      };
      actionable = {
        auth_key_path = age.secrets.netbird_actionable_tghanken_client.path;
        port = 51822;
        openFirewall = true;
        hardened = false;
      };
    };
  };

  # age.secrets.netbird_key.file = ../secrets/secret_files/encrypted/netbird_taylor_client.age;
  # services.netbird_user.auth_key_path = age.secrets.netbird_key.path;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  environment.systemPackages = with pkgs; [
    teams-for-linux
    zoom-us
    slack
    spotify
  ];

  # Enable the Cinnamon Desktop Environment.
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;

  programs.gnome-terminal.enable = false;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
}
