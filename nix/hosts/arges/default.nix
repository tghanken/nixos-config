{inputs, ...}: {
  imports = [
    {
      config.facter.reportPath =
        if builtins.pathExists ./facter.json
        then ./facter.json
        else throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
    }

    # Hardware additions
    inputs.nixos-hardware.nixosModules.gmktec-nucbox-g3-plus

    # Role
    ../../roles/server/local.nix

    # User
    ../../users/tghanken.nix
  ];

  disko.devices = import ./disk-config.nix;
  networking.hostName = "arges";
  networking.hostId = "be6e3de2";

  system.stateVersion = "25.11";
}
