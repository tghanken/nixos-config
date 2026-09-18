# nixos-config

Declarative, multi-host NixOS configuration with 4-tier data lifecycle management, ZFS impermanence, Tailscale mesh networking, declarative Syncthing synchronization, and automated Restic backups.

---

## 4-Tier Data Lifecycle Architecture

All hosts categorize state into four distinct tiers to eliminate configuration drift while preserving essential data and warm build caches:

| Tier       | Classification              | Reboot Lifecycle | Local Snapshots | Remote Backups        | Cross-Host Sync    | Target ZFS Dataset / Path                                                                  |
| :--------- | :-------------------------- | :--------------- | :-------------- | :-------------------- | :----------------- | :----------------------------------------------------------------------------------------- |
| **Tier 1** | **Impermanent (Scratch)**   | Wiped on boot    | ❌ No           | ❌ No                 | ❌ No              | `zroot/local/root` (rolled back to `@blank` in initrd), `tmpfs` (`/tmp`)                   |
| **Tier 2** | **Ephemeral (Warm Caches)** | Preserved        | ❌ No           | ❌ No                 | ❌ No              | `zroot/cache/*` (`~/.cache`, `~/.cargo`, `pnpm`, `bun`, `docker`, `/data/models`, `steam`) |
| **Tier 3** | **Host Persistent**         | Preserved        | ✅ Yes          | ✅ Yes (`--tag host`) | ❌ No              | `zroot/safe/host` (`/persist/host` - machine identity, logs, host keys)                    |
| **Tier 4** | **User Persistent**         | Preserved        | ✅ Yes          | ✅ Yes (`--tag user`) | ✅ Yes (Syncthing) | `zroot/safe/user` (`/persist/user` - Repos, Documents, user dotfiles)                      |

---

## Quick Reference (`just`)

The repository includes a [justfile](file:///home/tghanken/Repos/os/nixos-config/justfile) with shortcuts for day-to-day operations:

| Task                 | Command                                  | Alias            | Description                                                                          |
| :------------------- | :--------------------------------------- | :--------------- | :----------------------------------------------------------------------------------- |
| **Format**           | `nix fmt`                                | —                | Format all files using DAG-ordered treefmt (Alejandra, Shfmt, Taplo, Yamlfmt, Oxfmt) |
| **Validate**         | `nix flake check`                        | —                | Run all CI checks, disk layout contracts, and package builds                         |
| **Update Layouts**   | `just update-disk-layouts`               | `just udl`       | Regenerate checked-in `disk-layout.json` contracts across all hosts                  |
| **Deploy Fleet**     | `just deploy [target]`                   | —                | Deploy changes to servers (or a target host/tag) via Colmena                         |
| **Deploy All**       | `just deploy-all`                        | —                | Apply closures to all reachable fleet nodes                                          |
| **Edit Secret**      | `just edit-secret <name>`                | `just es <name>` | Decrypt, edit, and re-encrypt a master secret with `agenix`                          |
| **Rekey Secrets**    | `just rekey-secrets`                     | `just rs`        | Rekey secrets for all hosts using `agenix-rekey`                                     |
| **Re-image Host**    | `just reimage <host> [target]`           | —                | Idempotently wipe, partition, restore backups, and reinstall a host                  |
| **Ingest Host Keys** | `just ingest-keys [hosts...]`            | —                | Retrieve and encrypt active SSH host keys from running nodes                         |
| **Pregenerate Sync** | `just pregenerate-syncthing-keys [host]` | `just psk`       | Pregenerate Syncthing cert, ID, and age key for workstations                         |
| **Ingest Sync IDs**  | `just ingest-syncthing-ids`              | `just isi`       | Query running workstations for Syncthing device IDs (legacy fallback)                |

---

## Creating a New Machine (Step-by-Step)

### 1. Define Host Configuration

Create `nix/hosts/<hostname>/default.nix`:

```nix
{ inputs, ... }: {
  imports = [
    # Hardware additions (nixos-hardware or facter report)
    # Role
    ../../roles/server.nix # or ../../roles/workstation.nix
    # Features & Services as needed
  ];

  networking.hostId = "<8-hex-chars>"; # e.g. head -c 8 /etc/machine-id
  system.stateVersion = "25.11";

  # Storage: specify target disk device(s)
  storage.disks = [
    "/dev/disk/by-id/..."
  ];

  # Optional swap overrides (defaults are automatically derived from role):
  # storage.swap = {
  #   zfsEnd = "-58G";
  #   encryptedSize = "8G";
  # };
}
```

> [!TIP]
>
> - **Zero Registration Boilerplate:** Any directory in `nix/hosts/` with a `default.nix` is **automatically discovered** and added to `nixosConfigurations` and `colmena`.
> - **Role-Informed Layouts:** `roles/workstation.nix` and `roles/server.nix` automatically set `storage.role` and Colmena tags (`@workstation`, `@server`, `@server-local`, `@server-remote`).
> - **Remote VMs:** If `roles.server.qemu = true` is set, `storage.role` automatically becomes `"server-remote"` and `storage.disks` defaults to `["/dev/vda"]` (no `storage` block required).

### 2. Generate Disk Layout Contract

Run:

```bash
just update-disk-layouts # or: just udl
```

This generates `nix/hosts/<hostname>/disk-layout.json`, which CI checks against during `nix flake check`.

### 3. Pregenerate Syncthing Identity (Workstations Only)

If setting up a workstation (`roles/workstation.nix`), pregenerate its TLS keypair and Syncthing Device ID before deployment:

```bash
just pregenerate-syncthing-keys <hostname> # or: just psk <hostname>
```

This writes `nix/hosts/<hostname>/syncthing/{id, cert.pem, key.age}` and runs `agenix rekey`.

> [!IMPORTANT]
> Preregistration is **mandatory** for sync-active hosts. NixOS configuration builds will fail with an assertion error if `syncthing/cert.pem` and `syncthing/key.age` are missing.

> [!TIP]
> If you bootstrap using `reimage-host`, it will automatically detect that `<hostname>` is a workstation and generate these keys on the fly before running `agenix rekey`.

### 4. Deploy via `reimage-host`

If bootstrapping a bare-metal machine or non-NixOS live image:

```bash
nix run .#reimage-host -- <hostname> root@<IP> --kexec
```

`reimage-host` will automatically:

1. Detect that `<hostname>` lacks an identity, generate a new Ed25519 host keypair, write `key.pub`, and encrypt `key.age` using master keys.
2. Detect if `<hostname>` is a workstation and pregenerate Syncthing identity keys if not already present.
3. Run `agenix rekey` so the new host can decrypt its secrets.
4. Partition and format the machine with Disko.
5. Stage SSH host keys into `/persist/host/etc/ssh`.
6. Install the closure and reboot.

---

## Re-imaging an Existing Host (`reimage-host`)

To wipe a host's disks and reinstall cleanly while preserving secrets, identity, and persistent state:

```bash
just reimage <hostname> root@<IP>
```

### What Happens Automatically:

1. **Host Identity Preservation**: Verifies the remote host key matches `nix/hosts/<hostname>/key.pub` and decrypts `key.age` (or automatically ingests active keys from `$TARGET` over SSH if `key.age` is not yet saved).
2. **Disko Partitioning**: Partitions the disk(s) and creates fresh ZFS datasets.
3. **Automated Restic Restore**:
   - Queries the fleet's Cloudflare R2 repository for the latest snapshot matching `--host <hostname> --tag host`.
   - Restores `/persist/host` state directly into the deployment staging tree.
   - Restores `/persist/user` state matching `--host <hostname> --tag user` if a user backup exists.
4. **Key Staging**: Stages verified host keys into `/persist/host/etc/ssh`.
5. **Installation & Reboot**: Deploys the system closure and reboots into a clean, restored node.

### Flags:

- `--new-key`: Force generation of a new host Ed25519 keypair even if `key.pub` exists.
- `--kexec`: Use kexec tarball to bootstrap machines booted from a generic rescue ISO.
- `--no-restore`: Skip restoring Restic backups to start with a fresh `/persist` state.
- `--dry-run`: Validate staged keys and commands without executing disk operations.

---

## Day-to-Day Operations

### Code Quality & Formatting

We use [treefmt-nix](https://github.com/numtide/treefmt-nix) with a DAG-ordered pipeline configured in [nix/formatter/default.nix](file:///home/tghanken/Repos/os/nixos-config/nix/formatter/default.nix):

- **Nix**: `deadnix` $\to$ `nixf-diagnose` $\to$ `statix` $\to$ `alejandra`
- **Shell**: `shfmt` $\to$ `shellcheck`
- **Config**: `taplo` (TOML), `yamlfmt` (YAML), `just` (Justfile), `actionlint` (GitHub Workflows)
- **Docs & Web**: `oxfmt` (Markdown, JSON, Web)

Run:

```bash
nix fmt            # Formats all repository files
nix flake check    # Validates flake checks, derivations, and layout contracts
```

### Secrets Management (`agenix-rekey`)

Secrets are encrypted with age keys and distributed declaratively without a centralized `secrets.nix`:

```bash
just edit-secret <secret_name>   # (alias: just es <name>) Edit master secret
just rekey-secrets               # (alias: just rs) Rekey per-host secrets
```

- Master secrets: `nix/core/secrets/secret_files/*.age`
- Encrypted host keys: `nix/hosts/<host>/key.age`
- Per-host derived secrets: `nix/core/secrets/rekeyed/<host>/*.age`

### Fleet Deployment (`colmena`)

Deploy configuration changes to servers across the Tailscale network:

```bash
just deploy              # Deploys to all online servers (@server tag)
just deploy <hostname>   # Deploys to a specific host (e.g. just deploy arges)
just deploy-all          # Deploys to all fleet nodes
just deploy-dry          # Builds closures locally without pushing to targets
```

> [!NOTE]
> Node deployment tags (`@server`, `@server-local`, `@server-remote`, `@workstation`) and connection targets are automatically populated based on `storage.role` and host directory names. Target overrides can also be set via `TARGET_HOST_<name>` environment variables.

### Cross-Host Synchronization (Syncthing over Tailscale)

Workstations automatically discover peer workstations for real-time folder sync:

- **How it works**: [nix/features/sync.nix](file:///home/tghanken/Repos/os/nixos-config/nix/features/sync.nix) inspects `nix/hosts/` for any peer node containing `syncthing/id` and adds it to the private mesh on `tailscale0:22000`.
- **Declarative Identity in `syncthing/`**:
  - `syncthing/cert.pem`: Public TLS certificate placed in the Nix store and installed into `~/.config/syncthing/` at boot.
  - `syncthing/id`: Public device ID (SHA-256 of `cert.pem`) used by peer nodes to configure mesh pairings.
  - `syncthing/key.age`: Private TLS key encrypted with `agenix-rekey` and staged to `~/.config/syncthing/` with mode `0600` via systemd `ExecStartPre`.
- **Mandatory Preregistration**:
  ```bash
  just pregenerate-syncthing-keys <hostname> # (alias: just psk <hostname>)
  ```
  Sync-enabled workstations enforce an assertion that `syncthing/cert.pem` and `syncthing/key.age` must be present before the build succeeds, preventing accidental deployments without sync credentials.
- **Sync Folders**: Shared folders (`Documents`, `Pictures`) are registered by feature/role modules and automatically synchronize across all discovered peer workstations.

### Backups (`restic`)

- **Single Repository Deduplication**: All hosts back up to a shared Cloudflare R2 repository (`s3:https://<account>.r2.cloudflarestorage.com/<bucket>/nixos`). Content-defined chunking (CDC) deduplicates common packages, code, and configurations across the fleet.
- **Tag Isolation**:
  - `host-state`: Backs up `/persist/host` with `--tag host` and `--host <hostname>`.
  - `user-state`: Backs up `/persist/user` with `--tag user`.
- **Prune Coordination**: Pruning (`forget --prune`) requires exclusive locks. Only the primary workstation (`hercules`, configured via `isPrimary = true`) executes pruning timers to avoid lock collisions.
