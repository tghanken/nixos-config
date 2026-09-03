# Storage Walkthrough & Runbook: Impermanence, ZFS & Restic

Operational runbook and implementation walkthrough for the storage overhaul on **hercules** and **pegasus**.

---

## 1. What Has Been Implemented in Code

### Declarative Disko Dataset Hierarchy
* **Files**:
  * [nix/hosts/hercules/disk-config.nix](file:///home/tghanken/Repos/os/nixos-config/nix/hosts/hercules/disk-config.nix)
  * [nix/hosts/pegasus/disk-config.nix](file:///home/tghanken/Repos/os/nixos-config/nix/hosts/pegasus/disk-config.nix)
* **Features**:
  * Root pool defaults to `com.sun:auto-snapshot = false` and `mountpoint = null`.
  * `local/` un-snapshotted datasets: `root` (`/`, snapshotted to `@blank` at creation), `nix` (`/nix`), `var` (`/var`), `docker` (`/var/lib/docker`), `cache` (`~/.cache`), `cargo` (`~/.cargo`), `pnpm` (`~/.local/share/pnpm`), `bun` (`~/.bun`), `steam` (`~/.local/share/Steam`), `models` (`/data/models`).
  * `safe/` snapshotted datasets: `persist` (`/persist`).
  * `reserved` dataset: 15 GB unmounted reservation to avoid out-of-space pool lockups.

### Declarative Impermanence Module
* **File**: [nix/modules/nixos/impermanence.nix](file:///home/tghanken/Repos/os/nixos-config/nix/modules/nixos/impermanence.nix)
* **Features**:
  * Systemd initrd stage-1 service `initrd-rollback` with `requiredBy = ["sysroot.mount"]` and `before = ["sysroot.mount"]` guaranteeing rollback finishes before sysroot is mounted.
  * Ensures `/persist` and `/var` are marked `neededForBoot = true`.
  * Automated `systemd.tmpfiles.rules` configuring ownership (`tghanken:users`) on user mountpoints under the ephemeral home.
  * Comprehensive persistent paths covering system identities, network, VPNs, desktop configs, dev repositories, and shells (`.zsh_history`, `.bash_history`).

### Declarative Cloudflare R2 Restic Backup Module
* **File**: [nix/modules/nixos/restic.nix](file:///home/tghanken/Repos/os/nixos-config/nix/modules/nixos/restic.nix)
* **Features**:
  * Configures `services.restic.backups.system` targeted at `/persist`.
  * Native S3/R2 integration using `environmentFile` for `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
  * Nightly timer (`02:00`), pruning rules (`7 daily`, `4 weekly`, `12 monthly`), and standard dev exclusions.

---

## 2. Pre-Reimage Checklist (Execute on Host)

Before re-imaging `hercules` or `pegasus`:

```bash
# 1. Back up your existing repositories and documents to an external drive or remote host
rsync -avP /home/tghanken/Repos/ user@remote:/backup/Repos/
rsync -avP /home/tghanken/Documents/ user@remote:/backup/Documents/
rsync -avP /home/tghanken/.ssh/ user@remote:/backup/ssh/
rsync -avP /home/tghanken/.gnupg/ user@remote:/backup/gnupg/

# 2. Preserve your host SSH keys (needed so agenix can decrypt existing secrets)
sudo cp -a /etc/ssh/ssh_host_* /path/to/usb-or-backup/
```

---

## 3. Cloudflare R2 Secret Setup

### Step 1: Create Secrets in Agenix

1. Create the repository encryption password:
   ```bash
   just es restic_password
   ```
2. Create the Cloudflare R2 credentials environment file:
   ```bash
   just es restic_r2_env
   ```
   Contents of `restic_r2_env`:
   ```bash
   AWS_ACCESS_KEY_ID="<your-cloudflare-r2-access-key-id>"
   AWS_SECRET_ACCESS_KEY="<your-cloudflare-r2-secret-access-key>"
   ```

3. Declare the secrets in [nix/modules/secrets/base.nix](file:///home/tghanken/Repos/os/nixos-config/nix/modules/secrets/base.nix):
   ```nix
   config.age.secrets = {
     restic_password.file = encrypted_path + "/restic_password.age";
     restic_r2_env.file = encrypted_path + "/restic_r2_env.age";
   };
   ```

---

## 4. Re-imaging via `nixos-anywhere`

Re-image the target machine over SSH from the installer ISO:

```bash
# Example for hercules
nixos-anywhere --flake .#hercules root@<installer-ip>
```

Disko will automatically:
1. Partition the drives and create the striped `zroot` pool.
2. Create all `local/` and `safe/` datasets.
3. Execute `postCreateHook` to capture the pristine `zroot/local/root@blank` snapshot.
4. Mount `/persist` and install NixOS.

---

## 5. Post-Install Activation

In [nix/hosts/hercules/configuration.nix](file:///home/tghanken/Repos/os/nixos-config/nix/hosts/hercules/configuration.nix):

```nix
  # Enable Impermanence
  services.impermanence = {
    enable = true;
    rollback = {
      enable = true;
      rootDataset = "zroot/local/root";
    };
  };

  # Enable Cloudflare R2 Restic Backups
  services.customRestic = {
    enable = true;
    repository = "s3:https://<account-id>.r2.cloudflarestorage.com/hercules-backups";
    passwordFile = config.age.secrets.restic_password.path;
    environmentFile = config.age.secrets.restic_r2_env.path;
  };
```

---

## 6. Verification Runbook

* **Verify Clean Root Rollback**:
  ```bash
  sudo touch /test-ephemeral
  sudo reboot
  # After reboot, /test-ephemeral must NOT exist
  ```
* **Verify Persistent State Survives**:
  ```bash
  touch /persist/test-persist
  sudo reboot
  # After reboot, /persist/test-persist MUST exist
  ```
* **Verify Restic Backup**:
  ```bash
  sudo systemctl start restic-backups-system.service
  sudo systemctl status restic-backups-system.service
  ```
