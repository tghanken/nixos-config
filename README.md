# nixos-config

## Getting Started (Wireless Local Computer)
- Build all packages: `nix-fast-build`
- Burn iso to a usb drive: `sudo dd bs=4M conv=fsync oflag=direct status=progress if=result-x86_64-linux.pkgs-node-bootstrap-iso/iso/nixos-25.11.20251204.c97c47f-x86_64-linux.iso of=/dev/sdX`
- Plug iso usb drive into computer and boot
- Login with user added to bootstrap iso
- Run `iwctl` to start wireless connection process
    - Run `station list` to get wireless interfaces
    - Run `station <interface> connect <SSID>` to connect to your wireless network

## Bootstrapping a Host (with pre-generated keys & agenix-rekey)

To ensure secrets decrypt seamlessly on first boot without a two-stage redeploy:

1. **Pre-generate the host SSH key on your workstation**:
   ```bash
   mkdir -p /tmp/bootstrap-<HOST>/etc/ssh
   ssh-keygen -t ed25519 -N "" -f /tmp/bootstrap-<HOST>/etc/ssh/ssh_host_ed25519_key -C "root@<HOST>"
   chmod 600 /tmp/bootstrap-<HOST>/etc/ssh/ssh_host_ed25519_key
   ```

2. **Save the public key to the host directory**:
   ```bash
   cp /tmp/bootstrap-<HOST>/etc/ssh/ssh_host_ed25519_key.pub nix/hosts/<HOST>/key.pub
   ```

3. **Define the host in `nix/hosts/default.nix`** (with disk devices, role, etc.).

4. **Rekey secrets for the new host**:
   ```bash
   just rs   # or: agenix rekey
   ```

5. **Deploy with `nixos-anywhere` passing `--extra-files`**:
   ```bash
   nixos-anywhere --extra-files /tmp/bootstrap-<HOST> -f .#<HOST> root@<IP> --phases disko,install,reboot
   ```
   If necessary, generate facter report during install:
   ```bash
   --generate-hardware-config nixos-facter ./nix/hosts/<HOST>/facter.json
   ```

6. **Clean up temporary keys**:
   ```bash
   rm -rf /tmp/bootstrap-<HOST>
   ```

## Secrets Management (`agenix-rekey`)

Secrets are managed declaratively with `agenix-rekey`. There is no `secrets.nix` file; recipient hosts are automatically inferred from the module hierarchy.

* **Edit or create a secret**:
  ```bash
  just es <secret_name>
  # or: agenix edit nix/core/secrets/secret_files/<secret_name>.age
  ```
* **Rekey secrets across all hosts**:
  ```bash
  just rs
  # or: agenix rekey
  ```
* **View secret content**:
  ```bash
  agenix view nix/core/secrets/secret_files/<secret_name>.age
  ```

Master secrets are located in `nix/core/secrets/secret_files/`. Rekeyed per-host secrets are stored in `nix/core/secrets/rekeyed/<host>/`.

## YubiKey Setup (Hardware Master Identity)

Workstations have `pcscd`, `yubikey-personalization`, and `age-plugin-yubikey` installed. When ready to use a YubiKey as your master identity:

1. Plug in your YubiKey and verify detection:
   ```bash
   age-plugin-yubikey -l
   ```
2. Generate an age identity stub (public metadata only, safe to commit):
   ```bash
   age-plugin-yubikey > nix/core/secrets/yubikey.pub
   ```
3. Update `age.rekey.masterIdentities` in `nix/core/secrets/default.nix`:
   ```nix
   masterIdentities = [
     ./yubikey.pub
   ];
   ```
4. Re-encrypt master secrets to the new master key:
   ```bash
   agenix update-masterkeys
   just rs
   ```
