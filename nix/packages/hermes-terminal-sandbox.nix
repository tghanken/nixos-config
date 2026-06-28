{ pkgs, ... }:
pkgs.dockerTools.buildImage {
  name = "hermes-terminal-sandbox";
  tag = "latest";

  fromImage = "nikolaik/python-nodejs:python3.11-nodejs20";

  # Install Determinate Nix
  runAsRoot = ''
    set -eu

    # System deps for nix installer
    apt-get update
    apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils
    rm -rf /var/lib/apt/lists/*

    # Create temp dir for installer (Docker sandbox mounts /tmp as noexec)
    mkdir -p /tmp/nix-install

    # Install Determinate Nix (--init none: no systemd in container)
    TMPDIR=/tmp/nix-install curl -LsSf https://install.determinate.systems/nix \
      | sh -s -- install linux --no-confirm --init none
    rm -rf /tmp/nix-install
  '';

  config = {
    Env = [
      "PATH=/nix/var/nix/profiles/default/bin:${pkgs.stdenv.hostPlatform.config}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ];
  };
}
