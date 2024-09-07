{
  # boot.shell_on_fail = true;
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
    };
    grub = {
      enable = true;
      # shell_on_fail = true;
      configurationLimit = 10;
      zfsSupport = true;
      efiSupport = true;
      mirroredBoots = [
        { devices = [ "nodev" ]; path = "/boot"; }
      ];
    };
  };
}