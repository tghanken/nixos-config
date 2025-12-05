nix run github:nix-community/nixos-anywhere -- \
    --copy-host-keys \
    --flake .#syno-vm \
    root@192.168.20.96