{flake, ...}: {
  imports = [
    flake.nixosModules.bootstrap
    flake.nixosModules.kernel
    flake.nixosModules.networking
    flake.modules.users.tghanken
    {
      networking.hostId = "12345678";
      boot.supportedFilesystems = ["zfs"];
      system.stateVersion = "25.11";
    }
  ];
}