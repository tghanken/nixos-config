# Used only in the bootstrap iso
{flake, ...}: {
  imports = [
    flake.nixosModules.base
    flake.nixosModules.installer
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
