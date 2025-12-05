# Install profile - Applied to hosts being installed (adds disko)
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./bootstrap.nix
    inputs.disko.nixosModules.disko
    ../install/bootloader/bootloader.nix
    ../install/locale/locale.nix
  ];
}
