nix-store --gc;

nixos-rebuild build --flake .#inwin-tower;

nix-store --gc;

sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes \
    run 'github:nix-community/disko#disko-install' -- \
    --flake '.#inwin-tower' \
    --disk boot /dev/disk/by-id/nvme-INTEL_SSDPEDMW400G4_CVCQ6453007T400IGN \
    --disk f1 /dev/disk/by-id/nvme-CT1000P3SSD8_2320E6D67715 \
    --disk f2 /dev/disk/by-id/nvme-CT1000P3SSD8_2320E6D67656 \
    --disk bulk1 /dev/disk/by-id/ata-Hitachi_HUA723020ALA641_YGG3E3LA;
