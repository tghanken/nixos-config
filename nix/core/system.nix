{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.determinate.nixosModules.default
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Boot loader & ZFS services
  boot = {
    supportedFilesystems = ["zfs"];
    kernelPackages = pkgs.linuxPackages_6_18; # Fixes broken zfs package. See https://github.com/NixOS/nixos-hardware/issues/1675
    zfs = {
      package = pkgs.zfs_2_4; # Also needed for kernel fixes
      devNodes = "/dev/disk/by-partlabel";
      forceImportRoot = false;
    };
    loader.grub = {
      enable = lib.mkDefault true;
      configurationLimit = 10;
      zfsSupport = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      mirroredBoots = [
        {
          devices = ["nodev"];
          path = "/boot";
        }
      ];
    };
  };

  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };

  # Networking
  networking.networkmanager.enable = true;
  networking.useNetworkd = true;
  networking.dhcpcd.enable = false;

  # Determinate Nix daemon tuning
  environment.etc."nix/nix.custom.conf".text = "eval-cores = 0";

  # Nix daemon settings
  nix.settings = {
    connect-timeout = 1;
    download-attempts = 1;
    log-lines = 25;
    max-jobs = "auto";
    min-free = 128000000;
    max-free = 1000000000;
    fallback = true;
    warn-dirty = false;
    keep-outputs = true;
    auto-optimise-store = true;

    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://nix-community.cachix.org"
      "https://niks3.actionable-internal.work"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "actionable-niks3:A3EpGS6+W9zj0r6tY3KPoODoBRELq70j+dkbhhgi7aQ="
    ];
  };

  # System packages used for bootstrapping
  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.git
    pkgs.nano
    pkgs.ripgrep
  ];
  environment.variables.EDITOR = "nano";

  # Timezone update service
  services.tzupdate.enable = true;

  # SSH server used for bootstrapping
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = (import ../features/secrets/keys.nix).tghanken;
  services.openssh.hostKeys = [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

  # Store manager (nh)
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
  };

  # Earlyoom
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
  };

  # Auto upgrade
  system.autoUpgrade = {
    enable = lib.mkDefault true;
    flake = "github:tghanken/nixos-config";
    flags = ["-L"];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };
}
