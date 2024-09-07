{
  boot.loader.grub = {
    enable = true;
    configurationLimit = 10;
    zfsSupport = true;
    efiSupport = true;
    mirroredBoots = [
      { devices = [ "nodev"]; path = "/boot"; }
    ];
  };

  boot.loader.efi.canTouchEfiVariables = true;
}