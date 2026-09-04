# nixos-config

## Getting Started (Wireless Local Computer)
- Build all packages: `nix-fast-build`
- Burn iso to a usb drive: `sudo dd bs=4M conv=fsync oflag=direct status=progress if=result-x86_64-linux.pkgs-node-bootstrap-iso/iso/nixos-25.11.20251204.c97c47f-x86_64-linux.iso of=/dev/sdX`
- Plug iso usb drive into computer and boot
- Login with user added to bootstrap iso
- Run `iwctl` to start wireless connection process
    - Run `station list` to get wireless interfaces
    - Run `station <interface> connect <SSID>` to connect to your wireless network
- From another computer, run `nixos-anywhere -f .#<HOST> root@<IP> --phases disko,install,reboot`
    - If necessary generate a facter.json as part of this command by adding `--generate-hardware-config nixos-facter ./nix/hosts/<HOST>/facter.json`
