{pkgs, ...}: {
  # Fixes broken zfs package. See https://github.com/NixOS/nixos-hardware/issues/1675
  boot.kernelPackages = pkgs.linuxPackages_6_17;
}
