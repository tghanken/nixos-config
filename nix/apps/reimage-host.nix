{
  pkgs,
  lib,
  nixos-anywhere,
  agenix-rekey-pkg ? null,
}: let
  keysLib = import ../lib/keys.nix {inherit lib;};
  masterRecipientsFile = pkgs.writeText "master-recipients.txt" (
    lib.concatStringsSep "\n" (keysLib.readUserKeys "tghanken") + "\n"
  );
in
  pkgs.writeShellApplication {
    name = "reimage-host";
    runtimeInputs =
      [
        pkgs.rage
        pkgs.openssh
        pkgs.coreutils
        pkgs.git
        pkgs.restic
        pkgs.syncthing
        nixos-anywhere
      ]
      ++ lib.optional (agenix-rekey-pkg != null) agenix-rekey-pkg;

    text = ''
      set -euo pipefail

      usage() {
        cat <<'EOF'
      Usage: reimage-host <host> [target] [options] [-- <extra nixos-anywhere args...>]

      Idempotently re-images a host while preserving its SSH host identity and
      agenix-rekey decryption capability across full disk wipes. Automatically
      detects and restores the latest Restic backup into /persist/host and
      /persist/user if available.

      Arguments:
        host              Name of the host in self.nixosConfigurations (e.g. arges, hercules)
        target            Target SSH connection string (default: root@<host>)

      Options:
        --kexec           Enable kexec phase for bootstrapping non-NixOS nodes
                          (equivalent to --phases kexec,disko,install,reboot)
        --phases <p>      Explicit nixos-anywhere phases (default: disko,install,reboot)
        --no-restore      Do not attempt to restore Restic backups
        --dry-run         Print commands and inspect staged keys without executing
        --debug           Enable bash xtrace and pass --debug to nixos-anywhere
        -h, --help        Show this help message
      EOF
      }

      if [ $# -eq 0 ]; then
        usage
        exit 1
      fi

      HOST=""
      TARGET=""
      PHASES="disko,install,reboot"
      NO_RESTORE=false
      DRY_RUN=false
      DEBUG=false
      EXTRA_ARGS=()

      while [ $# -gt 0 ]; do
        case "$1" in
          -h|--help)
            usage
            exit 0
            ;;
          --kexec)
            PHASES="kexec,disko,install,reboot"
            shift
            ;;
          --phases)
            PHASES="$2"
            shift 2
            ;;
          --no-restore)
            NO_RESTORE=true
            shift
            ;;
          --dry-run)
            DRY_RUN=true
            shift
            ;;
          --debug)
            DEBUG=true
            shift
            ;;
          --)
            shift
            EXTRA_ARGS=("$@")
            break
            ;;
          -*)
            echo "ERROR: Unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
          *)
            if [ -z "$HOST" ]; then
              HOST="$1"
            elif [ -z "$TARGET" ]; then
              TARGET="$1"
            else
              EXTRA_ARGS+=("$1")
            fi
            shift
            ;;
        esac
      done

      if [ -z "$HOST" ]; then
        echo "ERROR: Missing required argument <host>." >&2
        exit 1
      fi

      if [ -z "$TARGET" ]; then
        TARGET="root@$HOST"
      fi

      if [ "$DEBUG" = true ]; then
        set -x
      fi

      HOST_DIR="nix/hosts/$HOST"
      if [ ! -d "$HOST_DIR" ]; then
        echo "ERROR: Host directory '$HOST_DIR' not found!" >&2
        echo "Valid hosts in repo:" >&2
        for d in nix/hosts/*/; do
          basename "$d" >&2
        done
        exit 1
      fi

      KEY_AGE="$HOST_DIR/key.age"
      KEY_PUB="$HOST_DIR/key.pub"

      # Native tmpdir tooling with secure permissions
      STAGING_DIR="$(mktemp -d -t nixos-reimage.XXXXXXXXXX)"
      trap 'rm -rf "$STAGING_DIR"' EXIT INT TERM
      chmod 700 "$STAGING_DIR"

      PRIV_KEY="$STAGING_DIR/id_ed25519"
      PUB_KEY="$STAGING_DIR/id_ed25519.pub"

      # ------------------------------------------------------------
      # Phase 1: Identity Resolution & Key Decryption
      # ------------------------------------------------------------
      if [ -f "$KEY_AGE" ]; then
        echo "==> Decrypting existing host private key from $KEY_AGE..."

        DECRYPTED=false
        # Try local user identities
        for id_candidate in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
          if [ -f "$id_candidate" ]; then
            if rage -d -i "$id_candidate" -o "$PRIV_KEY" "$KEY_AGE" 2>/dev/null; then
              DECRYPTED=true
              break
            fi
          fi
        done

        # Try age-plugin-yubikey if identity files weren't sufficient
        if [ "$DECRYPTED" = false ]; then
          if command -v age-plugin-yubikey >/dev/null 2>&1; then
            if rage -d -o "$PRIV_KEY" "$KEY_AGE" 2>/dev/null; then
              DECRYPTED=true
            fi
          fi
        fi

        if [ "$DECRYPTED" = false ]; then
          echo "FATAL ERROR: Failed to decrypt '$KEY_AGE' using available SSH/YubiKey identities!" >&2
          echo "Refusing to overwrite existing host identity without the matching decryption key." >&2
          exit 1
        fi

        chmod 600 "$PRIV_KEY"

        # Verify decrypted private key against key.pub if present
        if [ -f "$KEY_PUB" ]; then
          DERIVED_PUB=$(ssh-keygen -y -f "$PRIV_KEY" | tr -d '\r\n')
          EXPECTED_PUB=$(tr -d '\r\n' < "$KEY_PUB")
          if [ "$DERIVED_PUB" != "$EXPECTED_PUB" ]; then
            echo "FATAL ERROR: Decrypted key does not match public key in '$KEY_PUB'!" >&2
            echo "  Decrypted: $DERIVED_PUB" >&2
            echo "  Expected:  $EXPECTED_PUB" >&2
            exit 1
          fi
          echo "==> Verified: Private key matches committed $KEY_PUB"
          cp "$KEY_PUB" "$PUB_KEY"
          chmod 644 "$PUB_KEY"
        else
          ssh-keygen -y -f "$PRIV_KEY" > "$PUB_KEY"
          chmod 644 "$PUB_KEY"
          cp "$PUB_KEY" "$KEY_PUB"
          echo "==> Generated missing $KEY_PUB from decrypted private key."
        fi

      elif [ -f "$KEY_PUB" ]; then
        echo "FATAL ERROR: Found public key '$KEY_PUB' but missing encrypted private key '$KEY_AGE'!" >&2
        echo "Cannot re-image without the matching private key, as existing secrets cannot be decrypted." >&2
        echo "Run 'nix run .#ingest-host-keys' if the host is currently running, or delete '$KEY_PUB' if you wish to generate a brand new identity." >&2
        exit 1

      else
        echo "==> No existing identity found for $HOST. Initializing new host identity..."
        ssh-keygen -t ed25519 -N "" -f "$PRIV_KEY" -C "root@$HOST"
        chmod 600 "$PRIV_KEY"
        chmod 644 "$PUB_KEY"

        cp "$PUB_KEY" "$KEY_PUB"
        echo "==> Wrote new public key to $KEY_PUB"

        rage -R "${masterRecipientsFile}" -o "$KEY_AGE" "$PRIV_KEY"
        echo "==> Encrypted new private key to $KEY_AGE with master recipients."

        # Workstation Syncthing identity pregeneration
        if [ -f "nix/hosts/$HOST/default.nix" ] && grep -q "roles/workstation.nix" "nix/hosts/$HOST/default.nix"; then
          ST_DIR="nix/hosts/$HOST/syncthing"
          mkdir -p "$ST_DIR"
          ST_KEY_AGE="$ST_DIR/key.age"
          ST_CERT="$ST_DIR/cert.pem"
          ST_ID="$ST_DIR/id"
          if [ ! -f "$ST_KEY_AGE" ] || [ ! -f "$ST_CERT" ] || [ ! -f "$ST_ID" ]; then
            echo "==> Pregenerating Syncthing identity for workstation $HOST..."
            ST_TMP=$(mktemp -d)
            syncthing generate --home "$ST_TMP" >/dev/null 2>&1
            ST_DEV_ID=$(syncthing --home "$ST_TMP" device-id 2>/dev/null | tr -d '\r\n')
            echo "$ST_DEV_ID" > "$ST_ID"
            chmod 644 "$ST_ID"
            cp "$ST_TMP/cert.pem" "$ST_CERT"
            chmod 644 "$ST_CERT"
            rage -R "${masterRecipientsFile}" -o "$ST_KEY_AGE" "$ST_TMP/key.pem"
            chmod 644 "$ST_KEY_AGE"
            rm -rf "$ST_TMP"
            echo "==> Wrote Syncthing identity ($ST_DEV_ID) and encrypted key for $HOST."
          fi
        fi

        if command -v agenix >/dev/null 2>&1; then
          echo "==> Running agenix rekey for new host..."
          agenix rekey || echo "WARNING: agenix rekey failed. Run 'just rs' manually before deployment." >&2
        fi
      fi

      # Stage keys into standard and impermanence paths
      mkdir -p "$STAGING_DIR/etc/ssh"
      mkdir -p "$STAGING_DIR/persist/host/etc/ssh"
      cp "$PRIV_KEY" "$STAGING_DIR/etc/ssh/ssh_host_ed25519_key"
      cp "$PUB_KEY" "$STAGING_DIR/etc/ssh/ssh_host_ed25519_key.pub"
      cp "$PRIV_KEY" "$STAGING_DIR/persist/host/etc/ssh/ssh_host_ed25519_key"
      cp "$PUB_KEY" "$STAGING_DIR/persist/host/etc/ssh/ssh_host_ed25519_key.pub"
      chmod 600 "$STAGING_DIR/etc/ssh/ssh_host_ed25519_key" "$STAGING_DIR/persist/host/etc/ssh/ssh_host_ed25519_key"
      chmod 644 "$STAGING_DIR/etc/ssh/ssh_host_ed25519_key.pub" "$STAGING_DIR/persist/host/etc/ssh/ssh_host_ed25519_key.pub"

      echo "==> Staged SSH host keys in $STAGING_DIR"

      # ------------------------------------------------------------
      # Phase 2: Check for Backup Restoration Support
      # ------------------------------------------------------------
      BACKUP_ENABLED=$(nix eval .#nixosConfigurations."$HOST".config.features.backup.enable 2>/dev/null || echo false)
      BACKUP_REPO=$(nix eval --raw .#nixosConfigurations."$HOST".config.features.backup.repository 2>/dev/null || echo "")

      if [ "$BACKUP_ENABLED" = "true" ] && [ -n "$BACKUP_REPO" ] && [ "$NO_RESTORE" = false ]; then
        echo "==> Host $HOST has features.backup enabled ($BACKUP_REPO)."
        echo "==> Executing phased re-imaging with automated Restic restore..."

        # Step 1: Disko phase (partition and mount target datasets)
        DISKO_PHASES="disko"
        if [[ "$PHASES" == *"kexec"* ]]; then
          DISKO_PHASES="kexec,disko"
        fi

        DISKO_CMD=(
          nixos-anywhere
          --flake ".#$HOST"
          --phases "$DISKO_PHASES"
        )
        if [ "$DEBUG" = true ]; then DISKO_CMD+=(--debug); fi
        if [ ''${#EXTRA_ARGS[@]} -gt 0 ]; then DISKO_CMD+=("''${EXTRA_ARGS[@]}"); fi
        DISKO_CMD+=("$TARGET")

        if [ "$DRY_RUN" = true ]; then
          echo "==> [DRY RUN] Step 1 (Disko): ''${DISKO_CMD[*]}"
        else
          echo "==> Running Disko partitioning..."
          "''${DISKO_CMD[@]}"
        fi

        # Step 2: Restic restore into /mnt
        RESTIC_PASSWORD_FILE="nix/core/secrets/secret_files/restic_password.age"
        RESTIC_ENV_FILE="nix/core/secrets/secret_files/restic_r2_env.age"
        RESTIC_PW=""
        if [ -f "$RESTIC_PASSWORD_FILE" ]; then
          RESTIC_PW=$(rage -d -i "$HOME/.ssh/id_ed25519" "$RESTIC_PASSWORD_FILE" 2>/dev/null || true)
        fi

        if [ -f "$RESTIC_ENV_FILE" ]; then
          RESTIC_ENV_CONTENT=$(rage -d -i "$HOME/.ssh/id_ed25519" "$RESTIC_ENV_FILE" 2>/dev/null || true)
          if [ -n "$RESTIC_ENV_CONTENT" ]; then
            set -a
            eval "$RESTIC_ENV_CONTENT"
            set +a
          fi
        fi

        if [ "$DRY_RUN" = true ]; then
          echo "==> [DRY RUN] Step 2 (Restore): Would check $BACKUP_REPO for snapshots and restore to /mnt"
        elif [ -n "$RESTIC_PW" ]; then
          echo "==> Checking for existing host snapshots for $HOST in $BACKUP_REPO..."
          if RESTIC_PASSWORD="$RESTIC_PW" restic -r "$BACKUP_REPO" snapshots --host "$HOST" --tag host --json >/dev/null 2>&1; then
            echo "==> Found host snapshots! Restoring latest host snapshot into /mnt..."
            RESTIC_PASSWORD="$RESTIC_PW" restic -r "$BACKUP_REPO" restore latest --host "$HOST" --tag host --target /mnt
            echo "==> Host state restore complete."
          else
            echo "==> No host snapshots found for $HOST in $BACKUP_REPO. Continuing with fresh /persist/host."
          fi

          echo "==> Checking for user snapshots in $BACKUP_REPO..."
          if RESTIC_PASSWORD="$RESTIC_PW" restic -r "$BACKUP_REPO" snapshots --tag user --json >/dev/null 2>&1; then
            echo "==> Found user snapshots! Restoring latest user snapshot into /mnt..."
            RESTIC_PASSWORD="$RESTIC_PW" restic -r "$BACKUP_REPO" restore latest --tag user --target /mnt || true
            echo "==> User state restore complete."
          fi
        fi

        # Step 3: Install & Reboot
        INSTALL_CMD=(
          nixos-anywhere
          --extra-files "$STAGING_DIR"
          --flake ".#$HOST"
          --phases "install,reboot"
        )
        if [ "$DEBUG" = true ]; then INSTALL_CMD+=(--debug); fi
        if [ ''${#EXTRA_ARGS[@]} -gt 0 ]; then INSTALL_CMD+=("''${EXTRA_ARGS[@]}"); fi
        INSTALL_CMD+=("$TARGET")

        if [ "$DRY_RUN" = true ]; then
          echo "==> [DRY RUN] Step 3 (Install & Reboot): ''${INSTALL_CMD[*]}"
          echo "==> [DRY RUN] Staged files:"
          ls -laR "$STAGING_DIR"
          exit 0
        fi

        echo "==> Installing NixOS..."
        "''${INSTALL_CMD[@]}"

      else
        # Single-shot deployment when restic restore is not configured or disabled
        ANYWHERE_CMD=(
          nixos-anywhere
          --extra-files "$STAGING_DIR"
          --flake ".#$HOST"
          --phases "$PHASES"
        )
        if [ "$DEBUG" = true ]; then ANYWHERE_CMD+=(--debug); fi
        if [ ''${#EXTRA_ARGS[@]} -gt 0 ]; then ANYWHERE_CMD+=("''${EXTRA_ARGS[@]}"); fi
        ANYWHERE_CMD+=("$TARGET")

        if [ "$DRY_RUN" = true ]; then
          echo "==> [DRY RUN] Command that would be executed:"
          echo "    ''${ANYWHERE_CMD[*]}"
          echo "==> [DRY RUN] Extra-files staged:"
          ls -laR "$STAGING_DIR"
          exit 0
        fi

        echo "==> Executing nixos-anywhere..."
        "''${ANYWHERE_CMD[@]}"
      fi

      echo "============================================================"
      echo "==> Host $HOST re-imaging complete!"
      echo "==> The host is rebooting with its original SSH identity."
      echo "============================================================"
    '';
  }
