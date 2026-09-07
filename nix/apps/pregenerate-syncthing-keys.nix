{
  pkgs,
  lib,
  agenix-rekey-pkg ? null,
}: let
  keysLib = import ../lib/keys.nix {inherit lib;};
  masterRecipientsFile = pkgs.writeText "master-recipients.txt" (
    lib.concatStringsSep "\n" (keysLib.readUserKeys "tghanken") + "\n"
  );
in
  pkgs.writeShellApplication {
    name = "pregenerate-syncthing-keys";
    runtimeInputs =
      [
        pkgs.syncthing
        pkgs.rage
        pkgs.coreutils
        pkgs.git
        pkgs.gnugrep
      ]
      ++ lib.optional (agenix-rekey-pkg != null) agenix-rekey-pkg;

    text = ''
      set -euo pipefail

      usage() {
        cat <<'EOF'
      Usage: pregenerate-syncthing-keys [host...] [options]

      Pregenerates Syncthing TLS keypair (cert.pem & key.pem) and Device ID
      (syncthing.id) for NixOS workstations before initial deployment.
      Encrypts key.pem with master age recipients to nix/hosts/<host>/syncthing.key.age.

      Options:
        -f, --force       Overwrite existing Syncthing keys if present
        --no-rekey        Do not run agenix rekey after key generation
        -h, --help        Show this help message

      Examples:
        pregenerate-syncthing-keys                # Pregenerate for all workstations missing keys
        pregenerate-syncthing-keys hercules
        pregenerate-syncthing-keys pegasus --force
      EOF
      }

      HOSTS=()
      FORCE=false
      DO_REKEY=true

      while [ $# -gt 0 ]; do
        case "$1" in
          -h|--help)
            usage
            exit 0
            ;;
          -f|--force)
            FORCE=true
            shift
            ;;
          --no-rekey)
            DO_REKEY=false
            shift
            ;;
          -*)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
          *)
            HOSTS+=("$1")
            shift
            ;;
        esac
      done

      if [ ''${#HOSTS[@]} -eq 0 ]; then
        for dir in nix/hosts/*/; do
          host=$(basename "$dir")
          if [ -f "$dir/default.nix" ] && grep -q "roles/workstation.nix" "$dir/default.nix"; then
            HOSTS+=("$host")
          fi
        done
      fi

      if [ ''${#HOSTS[@]} -eq 0 ]; then
        echo "No workstation hosts found."
        exit 0
      fi

      echo "==> Pregenerating Syncthing keys for: ''${HOSTS[*]}"

      ANY_GENERATED=false

      for host in "''${HOSTS[@]}"; do
        host_dir="nix/hosts/$host"
        if [ ! -d "$host_dir" ]; then
          echo "ERROR: Directory $host_dir does not exist!" >&2
          exit 1
        fi

        st_dir="$host_dir/syncthing"
        mkdir -p "$st_dir"

        key_age="$st_dir/key.age"
        cert_file="$st_dir/cert.pem"
        id_file="$st_dir/id"

        if [ -f "$key_age" ] && [ -f "$cert_file" ] && [ -f "$id_file" ] && [ "$FORCE" = false ]; then
          current_id=$(cat "$id_file" 2>/dev/null || echo "unknown")
          echo "--> $host: Keys already exist (Device ID: $current_id). Skipping (use -f to force)."
          continue
        fi

        echo "--> Generating Syncthing keypair for $host..."
        TMP_DIR=$(mktemp -d)

        cleanup() {
          rm -rf "$TMP_DIR"
        }
        trap cleanup EXIT INT TERM

        syncthing generate --home "$TMP_DIR" >/dev/null 2>&1

        DEVICE_ID=$(syncthing --home "$TMP_DIR" device-id 2>/dev/null | tr -d '\r\n')
        if [ -z "$DEVICE_ID" ]; then
          echo "ERROR: Failed to calculate Syncthing device ID for $host" >&2
          exit 1
        fi

        echo "$DEVICE_ID" > "$id_file"
        chmod 644 "$id_file"

        cp "$TMP_DIR/cert.pem" "$cert_file"
        chmod 644 "$cert_file"

        rage -R "${masterRecipientsFile}" -o "$key_age" "$TMP_DIR/key.pem"
        chmod 644 "$key_age"

        cleanup
        trap - EXIT INT TERM

        echo "    Saved ID:   $id_file ($DEVICE_ID)"
        echo "    Saved cert: $cert_file"
        echo "    Saved key:  $key_age (encrypted)"
        ANY_GENERATED=true
      done

      if [ "$ANY_GENERATED" = true ] && [ "$DO_REKEY" = true ]; then
        if command -v agenix >/dev/null 2>&1; then
          echo "==> Running agenix rekey..."
          agenix rekey || echo "WARNING: agenix rekey failed. Run 'just rs' manually." >&2
        else
          echo "==> Keys generated. Run 'just rekey-secrets' (or 'just rs') to rekey for target hosts."
        fi
      fi

      echo "==> Finished."
    '';
  }
