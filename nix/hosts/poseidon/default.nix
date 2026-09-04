{...}: {
  imports = [
    ../../roles/server.nix
  ];

  roles.server.qemu = true;
  networking.hostId = "b9f3a8fc";
  system.stateVersion = "25.11";
}
