{
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

  # Disable USB autosuspend for bluetooth to prevent it from dropping out,
  # which is a known issue on Framework AMD AI 300 laptops
  boot.kernelParams = [
    "btusb.enable_autosuspend=0"
  ];
}
