{pkgs, ...}: {
  # Fixes broken zfs package. See https://github.com/NixOS/nixos-hardware/issues/1675
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.zfs.package = pkgs.zfs_2_4;
}
