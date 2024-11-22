{
  system.autoUpgrade = {
    enable = true;
    flake = "github:tghanken/nixos-config";
    flags = [
      "-L" # print build logs
    ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };
}
