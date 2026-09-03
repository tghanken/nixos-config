# Storage Walkthrough & Runbook: Impermanence, ZFS & Restic

Operational runbook and implementation walkthrough for the storage overhaul on **hercules** and **pegasus**.

---

## 1. What Has Been Implemented in Code

### ZFS Snapshot Retention Tuning
* **File**: [nix/modules/nixos/bootloader.nix](file:///home/tghanken/Repos/os/nixos-config/nix/modules/nixos/bootloader.nix#L25-L38)
* **Changes**:
  * Disabled 15-minute snapshots (`frequent = 0`).
  * Disabled 12-month retention (`monthly = 0`).
  * Configured rolling short-term retention: 12 hourly (`hourly = 12`), 7 daily (`daily = 7`), 4 weekly (`weekly = 4`).

### Auto-Snapshot Disabled on `/var`
* **Files**:
  * [nix/hosts/hercules/disk-config.nix](file:///home/tghanken/Repos/os/nixos-config/nix/hosts/hercules/disk-config.nix#L92-L96)
  * [nix/hosts/pegasus/disk-config.nix](file:///home/tghanken/Repos/os/nixos-config/nix/hosts/pegasus/disk-config.nix#L75-L79)
* **Changes**: Added `options."com.sun:auto-snapshot" = "false";` to eliminate Docker layer and CI runner bloat from snapshots.

### Declarative Impermanence Module
* **File**: [nix/modules/nixos/impermanence.nix](file:///home/tghanken/Repos/os/nixos-config/nix/modules/nixos/impermanence.nix)
* **Features**:
  * Systemd initrd stage-1 service `initrd-rollback` that executes `zfs rollback -r <rootDataset>@blank` before `sysroot.mount`.
  * Automatically applies `neededForBoot = true` to `/var`, `/home`, and `/persist` when defined in `config.fileSystems`.
  * Maps `/persist` to system identities (`/etc/machine-id`, `/etc/ssh/ssh_host_ed25519_key`, NetworkManager, Tailscale, system logs) and user data (`Documents`, `Downloads`, `Pictures`, `Repos`, `.ssh`, `.gnupg`, shell history).
  * Automatically configures `age.identityPaths` to check `/persist/etc/ssh/ssh_host_ed25519_key`.

### Declarative Restic Backup Module
* **File**: [nix/modules/nixos/restic.nix](file:///home/tghanken/Repos/os/nixos-config/nix/modules/nixos/restic.nix)
* **Features**:
  * Configures `services.restic.backups.system` targeted at `/persist`.
  * Default exclusions for caches, `node_modules`, `target`, `.cargo`, and temporary files.
  * Nightly systemd timer (`02:00`) and pruning rules (`7 daily`, `4 weekly`, `12 monthly`).

### Profile Export
* **File**: [nix/modules/profiles/shared-all.nix](file:///home/tghanken/Repos/os/nixos-config/nix/modules/profiles/shared-all.nix#L14-L15)
* **Features**: Both modules are imported across all hosts with `enable = false` by default, making them available on-demand with zero breaking changes.

---

## 2. Live Runbook: Step-by-Step Execution on Host

### Step 1: Isolate High-Churn Directories (Run Live Now)

Execute these commands directly on the host (e.g., `hercules` or `pegasus`) to stop high-churn data from polluting snapshots:

```bash
# 1. Isolate Steam games into an un-snapshotted dataset
if [ -d ~/.local/share/Steam ]; then
  mv ~/.local/share/Steam ~/.local/share/Steam.bak
  zfs create -o com.sun:auto-snapshot=false zroot/steam
  zfs set mountpoint=/home/tghanken/.local/share/Steam zroot/steam
  mv ~/.local/share/Steam.bak/* ~/.local/share/Steam/
  rmdir ~/.local/share/Steam.bak
fi

# 2. Isolate LM Studio / AI models (on hercules)
if [ -d ~/.cache/lm-studio ]; then
  mv ~/.cache/lm-studio ~/.cache/lm-studio.bak
  zfs create -o com.sun:auto-snapshot=false zroot/models
  zfs set mountpoint=/home/tghanken/.cache/lm-studio zroot/models
  mv ~/.cache/lm-studio.bak/* ~/.cache/lm-studio/
  rmdir ~/.cache/lm-studio.bak
fi

# 3. Isolate user cache directory
if [ -d ~/.cache ]; then
  zfs create -o com.sun:auto-snapshot=false zroot/cache
  zfs set mountpoint=/home/tghanken/.cache zroot/cache
fi
```

---

### Step 2: Prepare `/persist` and Blank Snapshot for Impermanence

Before enabling `services.impermanence.enable = true` on a host:

```bash
# 1. Create the persistent dataset
zfs create -o com.sun:auto-snapshot=true zroot/persist
zfs set mountpoint=/persist zroot/persist

# 2. Copy current host keys and machine-id to /persist
mkdir -p /persist/etc/ssh /persist/var/lib /persist/var/log
cp -a /etc/machine-id /persist/etc/machine-id
cp -a /etc/ssh/ssh_host_* /persist/etc/ssh/

# 3. Create the blank snapshot on your root dataset
# Note: For existing hosts, the root dataset is typically `zroot`
zfs snapshot zroot@blank
```

---

### Step 3: Enable Modules in Host Configuration

Add to `nix/hosts/<hostname>/configuration.nix` (e.g. [nix/hosts/hercules/configuration.nix](file:///home/tghanken/Repos/os/nixos-config/nix/hosts/hercules/configuration.nix)):

```nix
  # Enable Impermanence
  services.impermanence = {
    enable = true;
    rollback = {
      enable = true;
      rootDataset = "zroot"; # adjust to zroot/local/root if using redesigned disko
    };
  };

  # Enable Restic Backups
  services.customRestic = {
    enable = true;
    repository = "sftp:tghanken@hades:/var/backup/hercules";
    passwordFile = config.age.secrets.restic_password.path;
  };
```

---

## 3. Decisions & Actions Summary

| Item | Action Required | Command / Location |
| :--- | :--- | :--- |
| **Restic Secret** | Create encryption password in agenix | `just es restic_password` |
| **Restic Target** | Choose destination URL (SFTP vs S3/B2) | Set `services.customRestic.repository` |
| **Blank Snapshot** | Take snapshot before enabling rollback | `zfs snapshot zroot@blank` |
| **Host Key Copy** | Ensure `/etc/ssh/ssh_host_*` is in `/persist` | `cp -a /etc/ssh/ssh_host_* /persist/etc/ssh/` |
| **Live Datasets** | Move Steam & cache into dedicated datasets | Run script in Step 1 above |
