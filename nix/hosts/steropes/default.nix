{inputs, ...}: {
  imports = [
    inputs.nixos-hardware.nixosModules.gmktec-nucbox-g3-plus
    ../../roles/server.nix
  ];

  networking.hostId = "2ebead4e";
  system.stateVersion = "25.11";
}
