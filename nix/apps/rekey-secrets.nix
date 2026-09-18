{
  pkgs,
  lib,
  agenix-rekey-pkg ? null,
}: let
  keysLib = import ../lib/keys.nix {inherit lib;};
  agenixBin =
    if agenix-rekey-pkg != null
    then "${agenix-rekey-pkg}/bin/agenix"
    else "agenix";
in
  pkgs.writeShellApplication {
    name = "rekey-secrets";
    runtimeInputs =
      [
        pkgs.rage
        pkgs.openssh
        pkgs.coreutils
        pkgs.findutils
      ]
      ++ lib.optional (agenix-rekey-pkg != null) agenix-rekey-pkg;

    text = ''
      set -euo pipefail

      ${keysLib.shellHelpers}

      CHECK_ONLY=false
      PASSTHROUGH_ARGS=()
      for arg in "$@"; do
        if [ "$arg" = "--check-only" ]; then
          CHECK_ONLY=true
        else
          PASSTHROUGH_ARGS+=("$arg")
        fi
      done

      echo "============================================================"
      echo "==> Verifying host keys before rekeying..."
      echo "============================================================"

      TMP_DIR="$(mktemp -d -t nixos-rekey-verify.XXXXXXXXXX)"
      trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
      chmod 700 "$TMP_DIR"

      CHECK_FAILED=false
      VERIFIED_COUNT=0

      for host_dir in nix/hosts/*; do
        [ -d "$host_dir" ] || continue
        host="$(basename "$host_dir")"
        key_age="$host_dir/key.age"
        key_pub="$host_dir/key.pub"

        if [ ! -f "$key_age" ]; then
          echo "[ERROR] $host: Missing encrypted private key ($key_age)!" >&2
          echo "  Run 'nix run .#ingest-host-keys -- $host' to ingest or generate." >&2
          CHECK_FAILED=true
          continue
        fi

        if [ ! -f "$key_pub" ]; then
          echo "[ERROR] $host: Missing public key ($key_pub)!" >&2
          CHECK_FAILED=true
          continue
        fi

        decrypted_key="$TMP_DIR/''${host}_priv"
        DECRYPTED=false

        # Attempt decryption using user SSH identities
        for id_file in "''${AGENIX_REKEY_PRIMARY_IDENTITY:-}" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
          [ -n "$id_file" ] || continue
          if [ -f "$id_file" ]; then
            if rage -d -i "$id_file" -o "$decrypted_key" "$key_age" 2>/dev/null; then
              DECRYPTED=true
              break
            fi
          fi
        done

        # Attempt YubiKey if file identity failed
        if [ "$DECRYPTED" = false ] && command -v age-plugin-yubikey >/dev/null 2>&1; then
          if rage -d -o "$decrypted_key" "$key_age" 2>/dev/null; then
            DECRYPTED=true
          fi
        fi

        if [ "$DECRYPTED" = false ]; then
          echo "[ERROR] $host: Failed to decrypt $key_age using available master identities!" >&2
          CHECK_FAILED=true
          continue
        fi

        chmod 600 "$decrypted_key"

        if ! keys_match "$decrypted_key" "$key_pub"; then
          derived="$(derive_pubkey "$decrypted_key")"
          expected="$(normalize_pubkey "$key_pub")"
          echo "[ERROR] $host: key.pub does NOT match decrypted key.age!" >&2
          echo "  Derived from key.age: $derived" >&2
          echo "  Committed in key.pub: $expected" >&2
          CHECK_FAILED=true
          rm -f "$decrypted_key"
          continue
        fi

        rm -f "$decrypted_key"
        VERIFIED_COUNT=$((VERIFIED_COUNT + 1))
        echo "[OK] $host: key.age matches key.pub"
      done

      if [ "$CHECK_FAILED" = true ]; then
        echo "============================================================" >&2
        echo "FATAL: Host key verification failed! Aborting rekeying." >&2
        echo "Secrets will NOT be rekeyed until all key.pub values correspond to key.age." >&2
        echo "============================================================" >&2
        exit 1
      fi

      echo "==> All $VERIFIED_COUNT host key pairs verified successfully."

      if [ "$CHECK_ONLY" = true ]; then
        echo "==> Verification check passed (--check-only)."
        exit 0
      fi

      echo "==> Running agenix rekey..."
      echo "============================================================"

      if [ "''${#PASSTHROUGH_ARGS[@]}" -gt 0 ]; then
        exec ${agenixBin} rekey "''${PASSTHROUGH_ARGS[@]}"
      else
        exec ${agenixBin} rekey
      fi
    '';
  }
