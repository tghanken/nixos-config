{pkgs, ...}: {
  imports = [
    ../core
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
