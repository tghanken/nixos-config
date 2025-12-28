{
  inputs,
  flake,
  ...
}:
inputs.nixos-generators.nixosGenerate {
  system = "x86_64-linux";
  format = "iso";
  modules = [
    flake.modules.profiles.bootstrap
    flake.modules.users.tghanken
    {
      networking.hostId = "12345678";
      boot.supportedFilesystems = ["zfs"];
      system.stateVersion = "25.11";
    }
  ];
}
