{inputs, ...}: {
  imports = [
    inputs.nixos-hardware.nixosModules.gmktec-nucbox-g3-plus
    ../../roles/server.nix
  ];

  networking.hostId = "b6ca56e1";
  system.stateVersion = "25.11";
}
