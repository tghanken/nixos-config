{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../core
  ];

  # Storage role
  storage.role = "workstation";

  # Workstations (especially laptops) retain auto-upgrade when online
  system.autoUpgrade.enable = lib.mkDefault true;

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
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;
  programs.gnome-terminal.enable = false;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # YubiKey & Smartcard support
  services.pcscd.enable = true;
  services.udev.packages = [pkgs.yubikey-personalization];
  environment.systemPackages = with pkgs; [
    teams-for-linux
    zoom-us
    slack
    spotify
    yubikey-manager
    age-plugin-yubikey
  ];

  features.backup.enable = lib.mkDefault true;

  features.sync = {
    enable = lib.mkDefault true;
    folders = {
      documents = {
        path = "/home/tghanken/Documents";
        id = "user-documents";
      };
      pictures = {
        path = "/home/tghanken/Pictures";
        id = "user-pictures";
      };
    };
  };

  disko.devices.zpool.zroot.datasets."cache/build" = {
    type = "zfs_fs";
    mountpoint = "/home/tghanken/.cache";
    options."com.sun:auto-snapshot" = "false";
  };

  environment.persistence."/persist/host".directories = [
    "/var/lib/bluetooth"
  ];

  environment.persistence."/persist/user".users.tghanken = {
    directories = [
      # Browsers & Desktop GUI
      ".mozilla"
      ".config/spotify"
      ".config/google-chrome"
      ".config/chromium"
      ".config/ghostty"
      ".config/Slack"
      ".config/dconf"
      ".cinnamon"
      ".local/share/cinnamon"
      ".local/share/keyrings"
      ".config/pulse"

      # Antigravity IDE, agent brains, transcripts, and workspaces
      ".gemini"
      ".antigravity"
      ".antigravity-ide"
      ".config/Antigravity"
      ".config/Antigravity IDE"

      # Cloud, Kubernetes & Container Credentials
      ".cloudflared"
      ".kube"
      ".docker"
      ".config/gcloud"
      ".railway"
      ".talos"
      ".fly"

      # IDEs, Code Editors & Tooling
      ".vscode"
      ".vscode-shared"
      ".config/Code"
      ".cursor"
      ".config/Cursor"
      ".config/cursor"

      # CLI & Shell Navigation State
      ".local/share/zoxide"

      # AI Runtimes & Agent Models
      ".codex"
      ".pi"
      ".lmstudio"
      ".config/LM Studio"
      ".config/LM-Studio"
      ".config/opencode"
      ".local/share/opencode"
      ".local/share/kilo"

      # Communication & Meetings
      ".thunderbird"
      ".config/teams-for-linux"
      ".zoom"
    ];

    files = [
      # Display & Monitor Arrangements
      ".config/cinnamon-monitors.xml"
      ".config/monitors.xml"

      # Desktop Mime Associations & Meeting Configs
      ".config/mimeapps.list"
      ".config/zoom.conf"
      ".config/zoomus.conf"
    ];
  };
}
