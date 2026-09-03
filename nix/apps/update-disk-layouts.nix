{pkgs, ...}:
pkgs.writeShellApplication {
  name = "update-disk-layouts";
  runtimeInputs = [
    pkgs.nix
    pkgs.coreutils
  ];

  text = ''
    set -euo pipefail

    echo "==> Updating checked-in disk layout contracts..."

    HOSTS=(
      "arges"
      "brontes"
      "hades"
      "hercules"
      "pegasus"
      "poseidon"
      "steropes"
      "zeus"
    )

    for host in "''${HOSTS[@]}"; do
      echo "--> Generating nix/hosts/$host/disk-layout.json..."
      nix eval --impure --json ".#nixosConfigurations.$host.config.disko.devices" --apply '
        let
          diskoLib = import ./nix/lib/disko.nix { lib = import <nixpkgs/lib>; };
        in
          diskoLib.sanitizeDiskoDevices
      ' > "nix/hosts/$host/disk-layout.json"
    done

    echo "==> Successfully updated all host disk layout contracts."
  '';
}
