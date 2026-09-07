# nixos-config

## Getting Started (Wireless Local Computer)

- Build all packages: `nix-fast-build`
- Burn iso to a usb drive: `sudo dd bs=4M conv=fsync oflag=direct status=progress if=result-x86_64-linux.pkgs-node-bootstrap-iso/iso/nixos-25.11.20251204.c97c47f-x86_64-linux.iso of=/dev/sdX`
- Plug iso usb drive into computer and boot
- Login with user added to bootstrap iso
- Run `iwctl` to start wireless connection process
  - Run `station list` to get wireless interfaces
  - Run `station <interface> connect <SSID>` to connect to your wireless network

## Host Provisioning & Idempotent Re-imaging (`reimage-host`)

Host SSH identities are preserved across full disk wipes by storing their encrypted private key in `nix/hosts/<HOST>/key.age` (encrypted with master admin keys).

### Re-imaging an Existing Host

To wipe disks, format with Disko, and reinstall while preserving the host's identity and `agenix-rekey` decryption capabilities:

```bash
just reimage <HOST> <TARGET-IP>
# or:
nix run .#reimage-host -- <HOST> root@<TARGET-IP>
```

If the host is not yet running NixOS (e.g. booted into a generic live rescue environment), pass `--kexec`:

```bash
nix run .#reimage-host -- <HOST> root@<TARGET-IP> --kexec
```

### Ingesting Active Host Keys

To back up and encrypt the active SSH host private keys from running nodes into `nix/hosts/<HOST>/key.age`:

```bash
just ingest-keys
# or for a specific host:
nix run .#ingest-host-keys -- <HOST> --target root@<IP>
```

### Provisioning a Brand New Host

1. Define the host in `nix/hosts/default.nix` (with disks, role, etc.).
2. Run `nix run .#reimage-host -- <HOST> root@<IP>` (or `--kexec`).
   `reimage-host` will automatically generate a new keypair, commit `key.pub`, encrypt `key.age`, run `agenix rekey`, and deploy via `nixos-anywhere`.

## Fleet Deployment (`colmena`)

Server updates are managed via push-based Colmena. All evaluations and builds run locally on your controller hardware (`buildOnTarget = false`), pushing final closures to nodes over SSH/Tailscale.

- **Deploy all online servers (default)**:
  ```bash
  just deploy
  # or: colmena apply --impure --on @server --keep-going
  ```
- **Deploy a specific node or tag**:
  ```bash
  just deploy arges
  just deploy @workstation
  ```
- **Dry run / build closures without deploying**:
  ```bash
  just deploy-dry
  ```

## Secrets Management (`agenix-rekey`)

Secrets are managed declaratively with `agenix-rekey`. There is no `secrets.nix` file; recipient hosts are automatically inferred from the module hierarchy.

- **Edit or create a secret**:
  ```bash
  just es <secret_name>
  # or: agenix edit nix/core/secrets/secret_files/<secret_name>.age
  ```
- **Rekey secrets across all hosts**:
  ```bash
  just rs
  # or: agenix rekey
  ```
- **View secret content**:
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
