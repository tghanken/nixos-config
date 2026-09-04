{...}: {
  imports = [
    {
      config.facter.reportPath =
        if builtins.pathExists ./facter.json
        then ./facter.json
        else throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
    }

    # Role
    ../../roles/server/remote.nix

    # User
    ../../users/tghanken.nix
  ];

  disko.devices = import ./disk-config.nix;
  networking.hostName = "zeus";
  networking.hostId = "413627db";

  system.stateVersion = "25.11";
}
