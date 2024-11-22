# Creating a new host

1. Generate bootable bootstrap image for the new machine:
- Ex. x86 VM `nixos-generate -f iso --flake .#nixos-bootstrap --system x84_64-linux -o ./result |& nom`
- Ex. Rasperry Pi 4 `nixos-generate -f sd-aarch64 --flake .#nixos-bootstrap --system aarch64-linux -o ./result |& nom`
2. Boot the new machine from the generated image.
3. Make a new host configuration in the hosts directory, using one of the existing hosts as a template.
4. Connect to the new machine via ssh over tailscale: `ssh root@nixos-bootstrap`.  If you can't connect, you may need to refresh the tailscale key and rebuild the image.
6. Get the ssh keys on the host and add them to [secrets.nix](../secrets/secrets.nix)
7. Re-key the secrets using `agenix -r`
8. Run `lsblk` to identify the disks on the remote machine
9. Configure `devices.nix` in the new host directory to partition the disks as desired
10. Install the configuration on the host using: `nixos-anywhere --flake .#{your-new-hostname} --generate-hardware-config nixos-generate-config ./machines/hosts/{path/to}/hardware-configuration.nix root@nixos-bootstrap`