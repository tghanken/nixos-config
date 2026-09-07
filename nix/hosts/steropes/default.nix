{inputs, ...}: {
  imports = [
    inputs.nixos-hardware.nixosModules.gmktec-nucbox-g3-plus
    ../../roles/server.nix
  ];

  networking.hostId = "2ebead4e";
  system.stateVersion = "25.11";

  storage.disks = [
    "/dev/disk/by-id/mmc-TWSC_0x29214bef"
  ];
}
