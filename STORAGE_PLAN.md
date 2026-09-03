# Storage Redesign Plan: ZFS Dataset Tiering, Impermanence & Restic Backups

Comprehensive architectural plan for overhauling storage on **hercules** and **pegasus** from first principles.

---

## Architecture Overview

```text
zroot/
├── reserved                              (refreservation=15G, mountpoint=none)
│
├── local/                                (com.sun:auto-snapshot=false)
│   ├── root              -> /            (stateless root, rolled back to @blank on boot)
│   ├── nix               -> /nix         (Nix store, managed by nix-daemon)
│   ├── var               -> /var         (Docker, ephemeral container layers)
│   ├── cache             -> ~/.cache     (Browser cache, cargo, direnv, etc.)
│   ├── steam             -> ~/.local/share/Steam
│   └── models            -> ~/.cache/lm-studio (or /data/models)
│
└── safe/                                 (com.sun:auto-snapshot=true)
    └── persist           -> /persist     (The single source of truth for all persistent state)
```

---

## 1. ZFS Dataset Tiering

### Problem
* `com.sun:auto-snapshot = true` was set at the root pool level and inherited by `/var` and `/home`.
* High-churn data (Steam games, LM Studio models, Docker container layers, caches) locked into 12 months of snapshot history, causing pool exhaustion (96%+ capacity) and system lockups.

### First-Principles Solution
* **Split into `local` vs `safe` parents**:
  * **`local` (No Snapshots)**: Holds all reproducible, cache, or re-downloadable heavy binaries.
  * **`safe` (Snapshotted)**: Holds only user code, documents, cryptographic identities, and persistent system configuration.
* **Child Dataset Nesting**: ZFS allows mounting `local/cache` and `local/steam` directly inside `/home/tghanken/`. When snapshots run on `safe/persist` or `home`, ZFS automatically ignores mounted child datasets.

---

## 2. Impermanence (Erase-Your-Darlings)

### Principle
* The root filesystem (`/`) is ephemeral and rolled back to a clean `@blank` snapshot in stage-1 initrd on every boot.
* Only directories and files explicitly linked under `/persist` survive reboots.
* Eliminates configuration drift, orphan state, and unused files across reboots.

### Persistent Boundaries

#### System State (`/persist/system`)
* Machine identity: `/etc/machine-id`
* Host SSH keys: `/etc/ssh/ssh_host_ed25519_key` (and `.pub`)
* Network & VPN state: `/var/lib/tailscale`, `/var/lib/netbird`, `/etc/NetworkManager/system-connections`
* System logs and state: `/var/log`, `/var/lib/nixos`, `/var/lib/systemd`, `/var/lib/bluetooth`

#### User State (`/persist/home/tghanken`)
* SSH & GPG: `.ssh`, `.gnupg`
* Development & repositories: `Repos`, `Documents`, `Downloads`, `Pictures`
* Shell & environments: `.zsh_history`, `.local/share/direnv`, `.local/share/zoxide`
* Essential application configurations: `.config/gh`, `.config/spotify`, `.config/discord`

---

## 3. Automated Restic Backups

### Principle
* Because Impermanence forces all essential state into `/persist`, the backup scope is unambiguous: **backing up the machine means backing up `/persist`**.
* Caches, games, containers, and temporary files are completely isolated and never backed up.

### Backup Specifications
* **Engine**: Native NixOS `services.restic.backups.system`.
* **Schedule**: Nightly timer (`02:00`) with persistent catch-up if the system was offline.
* **Pruning**: Automated retention keeping 7 daily, 4 weekly, and 12 monthly snapshots.
* **Exclusions**: Standard build outputs and caches (`**/.cache`, `**/target`, `**/node_modules`, `**/.direnv`).

---

## Key Decisions Required

> [!IMPORTANT]
> Before enabling these features per host, review and decide on the following four architectural choices:

### Decision 1: Restic Repository Destination
* **Option A (Remote Tailscale Server - Recommended for Zero Cloud Cost)**:
  * Backup target: SFTP to one of your remote servers (`hades`, `zeus`, or `poseidon`) over Tailscale:
    `sftp:tghanken@hades:/var/backup/hercules`
* **Option B (Cloud Object Storage)**:
  * Backup target: Backblaze B2 or AWS S3:
    `s3:s3.us-west-000.backblazeb2.com/tghanken-backups/hercules`
  * Requires providing `restic_credentials.age` containing `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

### Decision 2: Secret Management for Restic Password
* Restic requires an encryption password.
* Create `nix/modules/secrets/secret_files/encrypted/restic_password.age` via agenix:
  ```bash
  just es restic_password
  ```
* Add the secret declaration to `nix/modules/secrets/base.nix`.

### Decision 3: AI Model Storage Policy (Hercules)
* LM Studio models (~50–200 GB) are stored in `~/.cache/lm-studio`.
* **Choice A (Disposable)**: Kept under `local/models` with no snapshots and no rollback. Models persist across reboots, but will be lost if disk is wiped.
* **Choice B (Persistent but Un-snapshotted)**: Mounted at `/persist/models` with symlink to `~/.cache/lm-studio`. Excluded from Restic backups via `exclude` pattern, but preserved across system re-installs.

### Decision 4: Migration Strategy (Live vs Reinstall)
* **Live In-Place Migration (Recommended)**:
  * Keep the existing disk partition layout.
  * Create `zroot/steam`, `zroot/models`, and `zroot/cache` live using `zfs create`.
  * Create `zroot/persist` live.
  * No reformatting or data loss required.
* **Fresh Reinstall via Disko (`nixos-anywhere`)**:
  * Only necessary if you want Disko to manage the exact parent dataset naming (`local/root`, `safe/persist`) from day 1.
