{flake, ...}: {
  imports = [
    flake.nixosModules.base
    flake.nixosModules.bootloader
    flake.nixosModules.determinate
    flake.nixosModules.kernel
    # flake.nixosModules.netbird
    flake.nixosModules.tailscale
    flake.nixosModules.networking

    flake.modules.builders.client
    flake.modules.secrets.base

    flake.modules.utils.auto-upgrade
    flake.modules.utils.earlyoom
  ];
}
