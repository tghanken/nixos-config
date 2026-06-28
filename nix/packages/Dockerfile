FROM nikolaik/python-nodejs:python3.11-nodejs20

# Install Determinate Nix in the Docker terminal backend sandbox.
# This gives agents access to `nix` for installing arbitrary tools
# at runtime without requiring pre-baked packages.

# Determinate Nix installer requires curl and a few deps.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils && \
    rm -rf /var/lib/apt/lists/*

# Create a temp dir for the installer (Docker sandbox mounts /tmp as noexec)
RUN mkdir -p /tmp/nix-install

# Install Determinate Nix with --init none (no systemd in container)
# TMPDIR must point to an exec-mountable location
RUN TMPDIR=/tmp/nix-install curl -LsSf https://install.determinate.systems/nix \
    | sh -s -- install linux --no-confirm --init none && \
    rm -rf /tmp/nix-install

# Make nix available on PATH for all shells (including non-login shells)
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

# Verify nix is accessible
RUN nix --version
