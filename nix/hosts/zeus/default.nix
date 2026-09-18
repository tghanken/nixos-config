{...}: {
  imports = [
    ../../roles/server.nix
  ];

  roles.server.qemu = true;
  networking.hostId = "413627db";
  system.stateVersion = "25.11";
}
