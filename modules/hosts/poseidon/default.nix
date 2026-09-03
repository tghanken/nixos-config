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
  networking.hostName = "poseidon";
  networking.hostId = "b9f3a8fc";

  system.stateVersion = "25.11";
}
