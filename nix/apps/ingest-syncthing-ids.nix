{pkgs, ...}:
pkgs.writeShellApplication {
  name = "ingest-syncthing-ids";
  runtimeInputs = [
    pkgs.openssh
    pkgs.coreutils
    pkgs.gnugrep
  ];

  text = ''
    set -euo pipefail

    usage() {
      cat <<'EOF'
    Usage: ingest-syncthing-ids [host...] [options]

    Connects to running NixOS workstations over SSH, queries Syncthing for its
    device ID, and saves it to nix/hosts/<host>/syncthing.id for automatic peer discovery.

    Options:
      --target <target> Target SSH connection string (valid only when a single host is specified)
      -h, --help        Show this help message

    Examples:
      ingest-syncthing-ids                   # Ingests from all configured workstations
      ingest-syncthing-ids hercules
      ingest-syncthing-ids pegasus --target root@100.64.0.5
    EOF
    }

    HOSTS=()
    CUSTOM_TARGET=""

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
        # Only ingest workstations by default
        if [ -f "$dir/default.nix" ] && grep -q "roles/workstation.nix" "$dir/default.nix"; then
          HOSTS+=("$host")
        fi
      done
    fi

    echo "==> Ingesting Syncthing device IDs for: ''${HOSTS[*]}"

    for host in "''${HOSTS[@]}"; do
      target="''${CUSTOM_TARGET:-root@$host}"
      if [ -d "nix/hosts/$host/syncthing" ]; then
        out_file="nix/hosts/$host/syncthing/id"
      else
        out_file="nix/hosts/$host/syncthing.id"
      fi

      echo "--> Fetching Syncthing ID from $host ($target)..."
      DEVICE_ID=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$target" '
        if [ -f /home/tghanken/.config/syncthing/cert.pem ] && command -v syncthing >/dev/null 2>&1; then
          syncthing --home /home/tghanken/.config/syncthing --device-id 2>/dev/null
        elif [ -f /home/tghanken/.config/syncthing/config.xml ]; then
          grep -oP "(?<=<device id=\")[^\"]*" /home/tghanken/.config/syncthing/config.xml | head -n 1
        elif [ -f /persist/user/home/tghanken/.config/syncthing/config.xml ]; then
          grep -oP "(?<=<device id=\")[^\"]*" /persist/user/home/tghanken/.config/syncthing/config.xml | head -n 1
        fi
      ' 2>/dev/null || true)

      if [ -n "$DEVICE_ID" ]; then
        echo "$DEVICE_ID" > "$out_file"
        echo "    Saved device ID to $out_file: $DEVICE_ID"
      else
        echo "    WARNING: Could not retrieve Syncthing device ID from $host. Is Syncthing running?" >&2
      fi
    done

    echo "==> Ingestion complete."
  '';
}
