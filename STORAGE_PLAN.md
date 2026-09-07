# Storage Architecture Plan: 4-Tier Lifecycle, Impermanence & Cross-Host Sync

Comprehensive architectural specification for the storage, persistence, synchronization, and backup model across **hercules**, **pegasus**, and the NixOS fleet.

---

## The 4-Tier Data Model

| Tier       | Classification              | Reboot Lifecycle | Local Snapshots | Remote Backups         | Cross-Host Sync        | Target ZFS Dataset / Mount                                                        |
| :--------- | :-------------------------- | :--------------- | :-------------- | :--------------------- | :--------------------- | :-------------------------------------------------------------------------------- |
| **Tier 1** | **Impermanent (Scratch)**   | Wiped on boot    | ❌ No           | ❌ No                  | ❌ No                  | `zroot/local/root` (rollback `@blank`), `tmpfs`                                   |
| **Tier 2** | **Ephemeral (Warm Caches)** | Preserved        | ❌ No           | ❌ No                  | ❌ No                  | `zroot/cache/*` (`~/.cache`, `~/.cargo`, `pnpm`, `bun`, `docker`, `/data/models`) |
| **Tier 3** | **Host Persistent**         | Preserved        | ✅ Yes          | ✅ Yes (tagged `host`) | ❌ No                  | `zroot/safe/host` (`/persist/host`)                                               |
| **Tier 4** | **User Persistent**         | Preserved        | ✅ Yes          | ✅ Yes (tagged `user`) | ✅ Yes (module-scoped) | `zroot/safe/user` (`/persist/user`)                                               |

---

## Architecture Overview

```text
zroot/
├── reserved                              (refreservation=15G, mountpoint=none)
│
├── local/                                (Tier 1: com.sun:auto-snapshot=false, mountpoint=none)
│   ├── root              -> /            (ephemeral root, rolled back to @blank on boot)
│   ├── nix               -> /nix         (Nix store, managed by nix-daemon)
│   └── var               -> /var         (ephemeral system state)
│
├── cache/                                (Tier 2: com.sun:auto-snapshot=false, mountpoint=none)
│   ├── build             -> ~/.cache     (User application and browser build caches)
│   ├── cargo             -> ~/.cargo     (Rust toolchains & registry cache)
│   ├── pnpm              -> ~/.local/share/pnpm (pnpm global store & global CLIs)
│   ├── bun               -> ~/.bun       (Bun cache & global CLIs)
│   ├── docker            -> /var/lib/docker (Dedicated ZFS driver storage for Docker)
│   ├── steam             -> ~/.local/share/Steam (Game binaries)
│   └── models            -> /data/models (AI weights shared across LLM runtimes)
│
└── safe/                                 (com.sun:auto-snapshot=true, mountpoint=none)
    ├── host              -> /persist/host (Tier 3: host-bound identity, machine-id, logs)
    └── user              -> /persist/user (Tier 4: syncable user workspace, documents, dotfiles)
```

---

## 1. Impermanence Architecture

### System State (`/persist/host`)

- **Machine identity**: `/etc/machine-id`
- **Host SSH keys**: `/etc/ssh/ssh_host_ed25519_key` (and `.pub`)
- **Network & VPN state**: `/var/lib/tailscale`, `/var/lib/bluetooth`, `/etc/NetworkManager/system-connections`
- **System logs and state**: `/var/log`, `/var/lib/nixos`, `/var/lib/systemd`

### User State (`/persist/user`)

- **Core workspace**: `~/Repos`, `~/Documents`, `~/Downloads`, `~/Pictures`
- **Cryptographic identities**: `~/.ssh`, `~/.gnupg`
- **Shell history**: `~/.zsh_history`, `~/.bash_history`
- **Application configurations**: `~/.config/gh`, `~/.config/zed`, `~/.mozilla`, `~/.config/spotify`, `~/.config/google-chrome`, `~/.config/chromium`, `~/.config/ghostty`, `~/.config/Slack`, `~/.local/share/direnv`

---

## 2. Declarative Cross-Host Synchronization (Syncthing over Tailscale)

- **Engine**: Syncthing bound to Tailscale private mesh interfaces (`tailscale0`).
- **Module-Aware Folder Registration**: Individual feature modules register sync folders into `features.sync.folders`:
  - `workstation.nix`: Registers `Documents` and `Pictures`.
  - `development.nix`: Registers selective development folders.
- **Persistent Identity**: Syncthing keys and databases are persisted under `/persist/user/tghanken/.config/syncthing` and `/persist/user/tghanken/.local/share/syncthing` to avoid device re-pairing across reboots.

---

## 3. Unified Restic Backups with Global Deduplication

### Single-Repository Best Practice

- All hosts back up to a **single unified repository** on Cloudflare R2 (`s3:https://<account>.r2.cloudflarestorage.com/<bucket>/nixos`).
- Restic Content-Defined Chunking (CDC) deduplicates common files globally across all nodes.

### Tagged Backup Jobs

1. **`host-state`**:
   - Path: `/persist/host`
   - Tag: `host`
   - Identifier: `--host <hostname>`
   - Pruning: Only run on the designated primary host (`hercules`) to prevent exclusive repository lock contention.
2. **`user-state`**:
   - Path: `/persist/user`
   - Tag: `user`
   - Pruning: Coordinated on primary host.

### Bare-Metal Restore Workflow

During `reimage-host`:

1. Stage-1 partitions and mounts target datasets (`/mnt/persist/host`, `/mnt/persist/user`).
2. Stage-2 queries the Restic repository for the latest snapshot tagged `host` for `--host $HOST` and restores it directly to `/mnt`.
3. Checks for latest `user` snapshots and restores them to `/mnt`.
4. Stages recovered SSH host keys into `/persist/host/etc/ssh`.
