nix-store --gc;

nixos-rebuild build --flake .#nixos-thinkpad;

nix-store --gc;

sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes \
    run 'github:nix-community/disko#disko-install' -- \
    --write-efi-boot-entries \
    --flake '.#nixos-thinkpad' \
    --disk boot /dev/nvme0n1;
