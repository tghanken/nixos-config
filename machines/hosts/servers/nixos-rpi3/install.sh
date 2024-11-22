sudo disko-install \
    --flake 'github:tghanken/nixos-config#nixos-rpi3' \
    --disk boot /dev/mmcblk0;

sudo zpool export zroot;
