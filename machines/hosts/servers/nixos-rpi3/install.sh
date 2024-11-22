sudo disko-install \
    --flake 'github:tghanken/playground/10-22-feat_add_rpi3_host#nixos-rpi3' \
    --disk boot /dev/mmcblk0;

sudo zpool export zroot;
