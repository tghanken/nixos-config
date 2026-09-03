# Storage Redesign Plan: ZFS Dataset Tiering, Impermanence & Restic Backups

Comprehensive architectural plan for overhauling storage on **hercules** and **pegasus** from first principles.

---

## Architecture Overview

```text
zroot/
├── reserved                              (refreservation=15G, mountpoint=none)
│
├── local/                                (com.sun:auto-snapshot=false, mountpoint=none)
│   ├── root              -> /            (ephemeral root, rolled back to @blank on boot)
│   ├── nix               -> /nix         (Nix store, managed by nix-daemon)
│   ├── var               -> /var         (VMs, system state, ephemeral container layers)
│   ├── docker            -> /var/lib/docker (Dedicated ZFS driver storage for Docker)
│   ├── cache             -> ~/.cache     (Browser cache, direnv, etc.)
│   ├── cargo             -> ~/.cargo     (Rust toolchains & registry cache)
│   ├── pnpm              -> ~/.local/share/pnpm (pnpm global store & global CLIs)
│   ├── bun               -> ~/.bun       (Bun cache & global CLIs)
│   ├── steam             -> ~/.local/share/Steam (Game binaries)
│   └── models            -> /data/models (AI weights shared across LLM runtimes)
│
└── safe/                                 (com.sun:auto-snapshot=true, mountpoint=none)
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
* **Pool-Level Default**: `rootFsOptions."com.sun:auto-snapshot" = "false"` ensures no dataset is ever snapshotted unless explicitly placed under `safe/`.
* **Consistency Across Hosts**: Both **hercules** (striped 2TB pool) and **pegasus** (single 1TB pool) share an identical dataset hierarchy. Empty datasets incur 0 extra storage and ensure uniform module definitions.

### Language Ecosystem Isolation (`cargo`, `pnpm`, `bun`)
* **Dedicated Un-snapshotted Stores**: Rust (`~/.cargo`), pnpm (`~/.local/share/pnpm`), and Bun (`~/.bun`) reside on dedicated datasets. Global binaries (`pnpm add -g`, `bun add -g`, `cargo install`) survive reboots without polluting snapshots or Restic backups.
* **Cross-Filesystem Hardlink Fallback**: `pnpm` automatically catches cross-device link boundaries (`EXDEV`) when linking into `~/Repos` (on `safe/persist`) and falls back to standard file copying, preventing package stores from polluting persistent snapshot histories.

---

## 2. Impermanence (Erase-Your-Darlings)

### Principle
* The root filesystem (`/`) is ephemeral and rolled back to a clean `@blank` snapshot in stage-1 initrd on every boot.
* User home (`/home/tghanken`) is ephemeral; only directories and files explicitly linked under `/persist` survive reboots.
* Eliminates configuration drift, orphan state, and unused files across reboots.

### Persistent Boundaries

#### System State (`/persist/system`)
* Machine identity: `/etc/machine-id`
* Host SSH keys: `/etc/ssh/ssh_host_ed25519_key` (and `.pub`)
* Network & VPN state: `/var/lib/tailscale`, `/var/lib/bluetooth`, `/etc/NetworkManager/system-connections`
* System logs and state: `/var/log`, `/var/lib/nixos`, `/var/lib/systemd`

#### User State (`/persist/home/tghanken`)
* SSH & GPG: `.ssh`, `.gnupg`
* Development & repositories: `Repos`, `Documents`, `Downloads`, `Pictures`
* Shell & environments: `.zsh_history`, `.bash_history`, `.local/share/direnv`, `.local/share/zoxide`
* Essential application configurations: `.config/gh`, `.config/spotify`, `.config/discord`, `.config/google-chrome`, `.thunderbird`

---

## 3. Automated Restic Backups to Cloudflare R2

### Principle
* Because Impermanence forces all essential state into `/persist`, the backup scope is unambiguous: **backing up the machine means backing up `/persist`**.
* Caches, games, containers, models, and temporary files are completely isolated and never backed up.

### Backup Specifications
* **Engine**: Native NixOS `services.restic.backups.system`.
* **Target**: Cloudflare R2 (S3-compatible, zero egress fees):
  `s3:https://<account-id>.r2.cloudflarestorage.com/<bucket-name>`
* **Credentials**:
  * Encryption password: `config.age.secrets.restic_password.path`
  * S3 environment: `config.age.secrets.restic_r2_env.path` (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`)
* **Schedule**: Nightly timer (`02:00`) with persistent catch-up.
* **Pruning**: Retention keeping 7 daily, 4 weekly, and 12 monthly snapshots.
* **Exclusions**: Standard build outputs and caches (`**/.cache`, `**/target`, `**/node_modules`, `**/.direnv`, `**/.cargo/registry`, `**/.cargo/git`).

---

## Decisions Summary

1. **Root & Home Strategy**: Strict Impermanence (Choice B) for both root and home.
2. **Disko Alignment**: Declarative layout in [disk-config.nix](file:///home/tghanken/Repos/os/nixos-config/nix/hosts/hercules/disk-config.nix); clean re-image via `nixos-anywhere`.
3. **AI Models**: Mounted to `/data/models` with LM Studio pointing directly to it (or symlinked from `~/.lmstudio/models`).
4. **Restic Destination**: Cloudflare R2 object storage.
5. **Pool Topology (Hercules)**: Striped 2TB pool maintained for maximum gaming and AI model capacity.
