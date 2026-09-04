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
        nixos-anywhere
      ]
      ++ lib.optional (agenix-rekey-pkg != null) agenix-rekey-pkg;

    text = ''
      set -euo pipefail

      usage() {
        cat <<'EOF'
      Usage: reimage-host <host> [target] [options] [-- <extra nixos-anywhere args...>]

      Idempotently re-images a host while preserving its SSH host identity and
      agenix-rekey decryption capability across full disk wipes.

      Arguments:
        host              Name of the host in self.nixosConfigurations (e.g. arges, hercules)
        target            Target SSH connection string (default: root@<host>)

      Options:
        --kexec           Enable kexec phase for bootstrapping non-NixOS nodes
                          (equivalent to --phases kexec,disko,install,reboot)
        --phases <phases> Explicitly specify nixos-anywhere phases
                          (default: disko,install,reboot)
        --dry-run         Verify and stage keys without executing nixos-anywhere
        --debug           Enable debug tracing in reimage-host and nixos-anywhere
        -h, --help        Show this help message

      Examples:
        reimage-host arges root@192.168.1.50
        reimage-host brontes root@brontes --kexec
        reimage-host hades root@10.0.0.12 --dry-run
      EOF
      }

      if [ $# -eq 0 ]; then
        usage
        exit 1
      fi

      HOST=""
      TARGET=""
      PHASES="disko,install,reboot"
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

      SSH_DIR="$STAGING_DIR/etc/ssh"
      mkdir -p "$SSH_DIR"
      chmod 755 "$STAGING_DIR/etc" "$SSH_DIR"

      PRIV_KEY="$SSH_DIR/ssh_host_ed25519_key"
      PUB_KEY="$SSH_DIR/ssh_host_ed25519_key.pub"

      echo "============================================================"
      echo "==> Re-imaging host: $HOST"
      echo "==> Target:          $TARGET"
      echo "==> Phases:          $PHASES"
      echo "============================================================"

      # ------------------------------------------------------------
      # Phase 1: Identity Resolution & Verification
      # ------------------------------------------------------------
      if [ -f "$KEY_AGE" ]; then
        echo "==> Found existing encrypted private key: $KEY_AGE"

        ID_FLAGS=()
        if [ -f "$HOME/.ssh/id_ed25519" ]; then
          ID_FLAGS+=("-i" "$HOME/.ssh/id_ed25519")
        fi
        if [ -f "$HOME/.ssh/id_rsa" ]; then
          ID_FLAGS+=("-i" "$HOME/.ssh/id_rsa")
        fi

        # Strict decryption check: must not fail silently or overwrite
        if ! rage -d "''${ID_FLAGS[@]}" "$KEY_AGE" > "$PRIV_KEY" 2>/dev/null; then
          echo "FATAL ERROR: Failed to decrypt '$KEY_AGE'!" >&2
          echo "Please ensure your master private key (~/.ssh/id_ed25519) or YubiKey is available." >&2
          echo "Refusing to proceed or regenerate identity to avoid permanent secret lock-out." >&2
          exit 1
        fi
        chmod 600 "$PRIV_KEY"

        if [ -f "$KEY_PUB" ]; then
          DERIVED_PUB=$(ssh-keygen -y -f "$PRIV_KEY")
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

        rage -a -R "${masterRecipientsFile}" -o "$KEY_AGE" "$PRIV_KEY"
        echo "==> Encrypted new private key to $KEY_AGE with master recipients."

        if command -v agenix >/dev/null 2>&1; then
          echo "==> Running agenix rekey for new host..."
          agenix rekey || echo "WARNING: agenix rekey failed. Run 'just rs' manually before deployment." >&2
        fi
      fi

      echo "==> Staged SSH host keys in $STAGING_DIR"

      # ------------------------------------------------------------
      # Phase 2: Wipe & Install via nixos-anywhere
      # ------------------------------------------------------------
      ANYWHERE_CMD=(
        nixos-anywhere
        --extra-files "$STAGING_DIR"
        --flake ".#$HOST"
        --phases "$PHASES"
      )

      if [ "$DEBUG" = true ]; then
        ANYWHERE_CMD+=(--debug)
      fi

      if [ ''${#EXTRA_ARGS[@]} -gt 0 ]; then
        ANYWHERE_CMD+=("''${EXTRA_ARGS[@]}")
      fi

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

      # ------------------------------------------------------------
      # Phase 3: Post-Install Data Hook (Extensible for Restic)
      # ------------------------------------------------------------
      # RESERVED: In future revisions, plug in restic backup restoration here:
      # if [ -n "''${RESTIC_RESTORE:-}" ]; then
      #   echo "==> Restoring restic snapshot for $HOST..."
      #   ...
      # fi

      echo "============================================================"
      echo "==> Host $HOST re-imaging complete!"
      echo "==> The host is rebooting with its original SSH identity."
      echo "============================================================"
    '';
  }
