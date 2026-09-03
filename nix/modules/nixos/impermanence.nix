{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.impermanence;
in {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  options.services.impermanence = {
    enable = mkEnableOption "Impermanence root rollback and persistence";
    persistPath = mkOption {
      type = types.str;
      default = "/persist";
      description = "Root path where persistent files and directories are mounted.";
    };
    rollback = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to roll back root dataset to @blank in initrd";
      };
      rootDataset = mkOption {
        type = types.str;
        default = "zroot/local/root";
        description = "ZFS root dataset name to roll back to @blank";
      };
    };
  };

  config = mkIf cfg.enable {
    # In systemd stage-1, roll back root dataset before mounting sysroot
    boot.initrd.systemd.services.initrd-rollback = mkIf cfg.rollback.enable {
      description = "Rollback ZFS root dataset to @blank";
      wantedBy = ["initrd.target"];
      after = ["zfs-import-zroot.service"];
      before = ["sysroot.mount"];
      path = [pkgs.zfs];
      unitConfig.DefaultDependencies = "no";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.zfs}/bin/zfs rollback -r ${cfg.rollback.rootDataset}@blank";
      };
    };

    # Filesystems used for persistent / ephemeral mounts must be marked neededForBoot
    fileSystems = {
      "/var".neededForBoot = mkIf (config.fileSystems ? "/var") (mkDefault true);
      "/home".neededForBoot = mkIf (config.fileSystems ? "/home") (mkDefault true);
      "${cfg.persistPath}".neededForBoot = mkIf (config.fileSystems ? "${cfg.persistPath}") (mkDefault true);
    };

    environment.persistence.${cfg.persistPath} = {
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd"
        "/var/lib/tailscale"
        "/var/lib/bluetooth"
        "/etc/NetworkManager/system-connections"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
      users.tghanken = {
        directories = [
          "Documents"
          "Downloads"
          "Pictures"
          "Repos"
          ".local/share/direnv"
          ".local/share/zoxide"
          ".config/gh"
          ".config/spotify"
          ".ssh"
          ".gnupg"
        ];
        files = [
          ".zsh_history"
        ];
      };
    };

    # Ensure agenix finds host keys regardless of early mount state
    age.identityPaths = [
      "${cfg.persistPath}/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key"
    ];
  };
}
