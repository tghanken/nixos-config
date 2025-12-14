{pkgs, ...}: {
  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # misc
    which
    tree
    zstd

    # nix related
    nix-tree
    nix-output-monitor

    # productivity
    firefox
    google-chrome
    gh

    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
    lshw
    mission-center
  ];
}