{
  system.autoUpgrade = {
    enable = true;
    flake = "github:tghanken/playground";
    flags = [
      "-L" # print build logs
    ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };
}
