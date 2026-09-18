{inputs, ...}: {
  imports = [
    inputs.nixos-hardware.nixosModules.gmktec-nucbox-g3-plus
    ../../roles/server.nix
  ];

  networking.hostId = "be6e3de2";
  system.stateVersion = "25.11";

  storage.disks = [
    "/dev/disk/by-id/mmc-TWSC_0x1f41b194"
  ];
}
