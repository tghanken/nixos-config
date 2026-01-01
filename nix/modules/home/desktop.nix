{
  flake,
  pkgs,
  ...
}: {
  imports = [
    flake.homeModules.headless
  ];

  # set cursor size and dpi for 4k monitor
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };

  programs.firefox.enable = true;
  programs.chromium = {
    enable = true;
    extensions = [
      {id = "nngceckbapebfimnlniiiahkandclblb";} # Bitwarden
    ];
  };

  home.packages = with pkgs; [
    mission-center
    google-chrome
  ];
}
