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

      ${keysLib.shellHelpers}

      usage() {
        cat <<'EOF'
      Usage: ingest-host-keys [host...] [options]

      Connects to running NixOS hosts over SSH, retrieves their active
      /etc/ssh/ssh_host_ed25519_key, updates nix/hosts/<host>/key.pub,
      and encrypts it into nix/hosts/<host>/key.age using admin master keys.

      Options:
        --target <target> Target SSH connection string (valid only when a single host is specified)
        --force           Overwrite existing key.pub and key.age
        --dry-run         Verify remote host keys without modifying files
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
          if [ -d "$d" ]; then
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

        if [ -f "$KEY_AGE" ] && [ -f "$KEY_PUB" ] && [ "$FORCE" = false ]; then
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

        # Derive normalized public key from fetched private key
        DERIVED_PUB="$(derive_pubkey "$FETCHED_KEY")"
        if [ -z "$DERIVED_PUB" ]; then
          echo "[ERROR] $HOST: Failed to derive public key from fetched private key!" >&2
          FAILED_COUNT=$((FAILED_COUNT + 1))
          rm -f "$FETCHED_KEY"
          continue
        fi

        # If key.pub exists and differs from fetched key, warn if not forcing
        if [ -f "$KEY_PUB" ]; then
          EXPECTED_PUB="$(normalize_pubkey "$KEY_PUB")"
          if [ "$DERIVED_PUB" != "$EXPECTED_PUB" ]; then
            if [ "$FORCE" = false ]; then
              echo "[ERROR] $HOST: Remote key does not match committed $KEY_PUB!" >&2
              echo "  Remote Public Key: $DERIVED_PUB" >&2
              echo "  Committed in repo: $EXPECTED_PUB" >&2
              echo "  Pass --force to overwrite both $KEY_PUB and $KEY_AGE with the live key." >&2
              FAILED_COUNT=$((FAILED_COUNT + 1))
              rm -f "$FETCHED_KEY"
              continue
            else
              echo "[INFO] $HOST: Remote key differs from $KEY_PUB. Overwriting both files (--force)."
            fi
          fi
        fi

        if [ "$DRY_RUN" = true ]; then
          echo "[DRY RUN] $HOST: Would update $KEY_PUB and encrypt to $KEY_AGE."
          SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
          rm -f "$FETCHED_KEY"
          continue
        fi

        # Write normalized public key
        echo "$DERIVED_PUB" > "$KEY_PUB"
        chmod 644 "$KEY_PUB"

        # Encrypt with master recipients (binary format)
        rage -R "${masterRecipientsFile}" -o "$KEY_AGE" "$FETCHED_KEY"
        chmod 644 "$KEY_AGE"
        rm -f "$FETCHED_KEY"
        echo "[OK] $HOST: Successfully updated $KEY_PUB and $KEY_AGE"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      done

      echo "============================================================"
      echo "Ingestion Summary: $SUCCESS_COUNT succeeded, $SKIPPED_COUNT skipped, $FAILED_COUNT failed."
      echo "============================================================"
    '';
  }
