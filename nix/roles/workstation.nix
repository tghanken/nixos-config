{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../core
    ../features/netbird.nix
  ];

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
      };
      Policy = {
        AutoEnable = "true";
      };
    };
  };
  boot.kernelParams = [
    "btusb.enable_autosuspend=0"
  ];

  # Sound with pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Netbird client
  age.secrets.netbird_taylor_client.file = ../features/secrets/secret_files/encrypted/netbird_taylor_client.age;
  age.secrets.netbird_actionable_tghanken_client.file = ../features/secrets/secret_files/encrypted/netbird_actionable_tghanken_client.age;
  services.netbird_user = {
    enable = true;
    clients = {
      default = {
        auth_key_path = config.age.secrets.netbird_taylor_client.path;
        port = 51821;
        openFirewall = true;
        hardened = false;
      };
      actionable = {
        auth_key_path = config.age.secrets.netbird_actionable_tghanken_client.path;
        port = 51822;
        openFirewall = true;
        hardened = false;
      };
    };
  };

  # Desktop environment for tghanken
  home-manager.users.tghanken = {
    xresources.properties = {
      "Xcursor.size" = 16;
      "Xft.dpi" = 172;
    };

    programs.firefox = {
      enable = true;
      configPath = ".mozilla/firefox";
    };
    programs.chromium = {
      enable = true;
      extensions = [
        {id = "nngceckbapebfimnlniiiahkandclblb";} # Bitwarden
      ];
    };

    programs.ghostty = {
      enable = true;
      systemd.enable = true;
    };

    home.packages = with pkgs; [
      mission-center
      google-chrome
    ];
  };

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
