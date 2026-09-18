{...}: {
  imports = [
    ../../roles/server.nix
  ];

  roles.server.qemu = true;
  networking.hostId = "72d0e8be";
  system.stateVersion = "25.11";
}
