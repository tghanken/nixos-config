{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkDefault types;
  cfg = config.services.impermanence;
in {
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  options.services.impermanence = {
    enable = mkEnableOption "Impermanence root rollback and persistence" // {default = true;};
    persistPath = mkOption {
      type = types.str;
      default = "/persist";
      description = "Root path where persistent files and directories are mounted.";
    };
    user = mkOption {
      type = types.str;
      default = "tghanken";
      description = "Primary user whose home directory is managed under impermanence.";
    };
    rollback = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to roll back root dataset to @blank in initrd.";
      };
      rootDataset = mkOption {
        type = types.str;
        default = "zroot/local/root";
        description = "ZFS root dataset name to roll back to @blank.";
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
      requiredBy = ["sysroot.mount"];
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
      "${cfg.persistPath}".neededForBoot = mkIf (config.fileSystems ? "${cfg.persistPath}") (mkDefault true);
    };

    # Automatically derive directory ownership for filesystems mounted inside user home or /data
    systemd.tmpfiles.rules = let
      userHome = "/home/${cfg.user}";
      managedMounts = lib.filterAttrs (mp: _: (lib.hasPrefix userHome mp && mp != userHome) || mp == "/data/models") config.fileSystems;
    in
      [
        "d ${userHome} 0700 ${cfg.user} users -"
        "d ${cfg.persistPath}${userHome} 0700 ${cfg.user} users -"
      ]
      ++ (lib.mapAttrsToList (mp: _: "d ${mp} 0755 ${cfg.user} users -") managedMounts);

    # Base OS persistent files and directories
    environment.persistence.${cfg.persistPath} = {
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
    };

    # Ensure agenix finds host keys regardless of mount state
    age.identityPaths = [
      "${cfg.persistPath}/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key"
    ];
  };
}
