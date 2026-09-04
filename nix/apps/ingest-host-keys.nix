{
  pkgs,
  lib,
}: let
  keysLib = import ../lib/keys.nix {inherit lib;};
  masterRecipientsFile = pkgs.writeText "master-recipients.txt" (
    lib.concatStringsSep "\n" (keysLib.readUserKeys "tghanken") + "\n"
  );
in
  pkgs.writeShellApplication {
    name = "ingest-host-keys";
    runtimeInputs = [
      pkgs.rage
      pkgs.openssh
      pkgs.coreutils
    ];

    text = ''
      set -euo pipefail

      usage() {
        cat <<'EOF'
      Usage: ingest-host-keys [host...] [options]

      Connects to running NixOS hosts over SSH, retrieves their active
      /etc/ssh/ssh_host_ed25519_key, verifies it matches nix/hosts/<host>/key.pub,
      and encrypts it into nix/hosts/<host>/key.age using admin master keys.

      Options:
        --target <target> Target SSH connection string (valid only when a single host is specified)
        --force           Re-encrypt and overwrite existing key.age
        --dry-run         Verify remote host keys against key.pub without saving key.age
        -h, --help        Show this help message

      Examples:
        ingest-host-keys                       # Ingests all reachable hosts
        ingest-host-keys arges                 # Ingests arges (targets root@arges)
        ingest-host-keys arges --target root@192.168.1.50
        ingest-host-keys hades poseidon zeus
      EOF
      }

      HOSTS=()
      CUSTOM_TARGET=""
      FORCE=false
      DRY_RUN=false

      while [ $# -gt 0 ]; do
        case "$1" in
          -h|--help)
            usage
            exit 0
            ;;
          --target)
            CUSTOM_TARGET="$2"
            shift 2
            ;;
          --force)
            FORCE=true
            shift
            ;;
          --dry-run)
            DRY_RUN=true
            shift
            ;;
          -*)
            echo "ERROR: Unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
          *)
            HOSTS+=("$1")
            shift
            ;;
        esac
      done

      if [ ''${#HOSTS[@]} -gt 1 ] && [ -n "$CUSTOM_TARGET" ]; then
        echo "ERROR: --target can only be used with a single host." >&2
        exit 1
      fi

      if [ ''${#HOSTS[@]} -eq 0 ]; then
        for d in nix/hosts/*; do
          if [ -d "$d" ] && [ -f "$d/key.pub" ]; then
            HOSTS+=("$(basename "$d")")
          fi
        done
      fi

      TMP_DIR="$(mktemp -d -t nixos-ingest.XXXXXXXXXX)"
      trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
      chmod 700 "$TMP_DIR"

      echo "============================================================"
      echo "==> Ingesting Host SSH Keys"
      echo "==> Hosts to process: ''${HOSTS[*]}"
      echo "============================================================"

      SUCCESS_COUNT=0
      SKIPPED_COUNT=0
      FAILED_COUNT=0

      for HOST in "''${HOSTS[@]}"; do
        HOST_DIR="nix/hosts/$HOST"
        KEY_AGE="$HOST_DIR/key.age"
        KEY_PUB="$HOST_DIR/key.pub"

        if [ ! -d "$HOST_DIR" ]; then
          echo "ERROR: Host directory '$HOST_DIR' not found!" >&2
          FAILED_COUNT=$((FAILED_COUNT + 1))
          continue
        fi

        if [ ! -f "$KEY_PUB" ]; then
          echo "WARNING: Missing '$KEY_PUB' for host '$HOST'. Skipping." >&2
          SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
          continue
        fi

        if [ -f "$KEY_AGE" ] && [ "$FORCE" = false ]; then
          echo "[SKIP] $HOST: $KEY_AGE already exists (use --force to overwrite)."
          SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
          continue
        fi

        TARGET="root@$HOST"
        if [ -n "$CUSTOM_TARGET" ]; then
          TARGET="$CUSTOM_TARGET"
        fi

        echo "==> Connecting to $TARGET to fetch /etc/ssh/ssh_host_ed25519_key..."

        FETCHED_KEY="$TMP_DIR/''${HOST}_key"
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$TARGET" "cat /etc/ssh/ssh_host_ed25519_key" > "$FETCHED_KEY" 2>/dev/null; then
          echo "[WARNING] $HOST: Could not reach $TARGET over SSH."
          FAILED_COUNT=$((FAILED_COUNT + 1))
          continue
        fi
        chmod 600 "$FETCHED_KEY"

        # Verify key matches committed key.pub
        DERIVED_PUB=$(ssh-keygen -y -f "$FETCHED_KEY" 2>/dev/null || true)
        EXPECTED_PUB=$(tr -d '\r\n' < "$KEY_PUB")

        if [ "$DERIVED_PUB" != "$EXPECTED_PUB" ]; then
          echo "[ERROR] $HOST: Fetched private key does not match committed $KEY_PUB!" >&2
          echo "  Remote Public Key: $DERIVED_PUB" >&2
          echo "  Committed in repo: $EXPECTED_PUB" >&2
          FAILED_COUNT=$((FAILED_COUNT + 1))
          rm -f "$FETCHED_KEY"
          continue
        fi

        if [ "$DRY_RUN" = true ]; then
          echo "[DRY RUN] $HOST: Remote key matches $KEY_PUB. Would encrypt to $KEY_AGE."
          SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
          rm -f "$FETCHED_KEY"
          continue
        fi

        # Encrypt with master recipients
        rage -a -R "${masterRecipientsFile}" -o "$KEY_AGE" "$FETCHED_KEY"
        rm -f "$FETCHED_KEY"
        echo "[OK] $HOST: Successfully encrypted key -> $KEY_AGE"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      done

      echo "============================================================"
      echo "Ingestion Summary: $SUCCESS_COUNT succeeded, $SKIPPED_COUNT skipped, $FAILED_COUNT failed."
      echo "============================================================"
    '';
  }
