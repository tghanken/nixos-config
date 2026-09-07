{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.features.backup;
in {
  options.features.backup = {
    enable = mkEnableOption "Declarative Restic backup client";

    backend = mkOption {
      type = types.enum ["r2" "rest" "custom"];
      default = "r2";
      description = "Backup target type ('r2' for Cloudflare S3, 'rest' for self-hosted REST server, 'custom' for arbitrary repository URI).";
    };

    repository = mkOption {
      type = types.str;
      default = "";
      description = "Restic repository URL (e.g. s3:https://<account>.r2.cloudflarestorage.com/<bucket> or rest:http://<host>:8000/<repo>).";
    };

    passwordFile = mkOption {
      type = types.nullOr types.str;
      default =
        if config.age.secrets ? restic_password
        then config.age.secrets.restic_password.path
        else null;
      description = "Path to file containing the repository password.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default =
        if config.age.secrets ? restic_r2_env
        then config.age.secrets.restic_r2_env.path
        else null;
      description = "Path to environment file containing S3/B2 credentials (e.g. AWS_ACCESS_KEY_ID).";
    };

    isPrimary = mkOption {
      type = types.bool;
      default = config.networking.hostName == "hercules";
      description = "Whether this host is the primary node responsible for pruning snapshots to avoid lock collisions.";
    };

    backupUser = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to back up Tier 4 user data (/persist/user).";
    };

    paths = mkOption {
      type = types.listOf types.str;
      default = ["/persist/host"];
      description = "List of host directories to back up.";
    };

    userPaths = mkOption {
      type = types.listOf types.str;
      default = ["/persist/user"];
      description = "List of user directories to back up.";
    };

    exclude = mkOption {
      type = types.listOf types.str;
      default = [
        "**/.cache"
        "**/.local/share/Trash"
        "**/target"
        "**/node_modules"
        "**/.direnv"
        "**/.cargo/registry"
        "**/.cargo/git"
        "result"
        "result-*"
        "**/.stversions"
        "**/.stfolder"
        "**/.syncthing.*.tmp"
        "**/*.sync-conflict-*"
        "**/.local/share/syncthing"
        "**/.config/syncthing"
      ];
      description = "List of glob patterns to exclude from backups.";
    };

    timerConfig = mkOption {
      type = types.attrsOf types.anything;
      default = {
        OnCalendar = "02:00";
        Persistent = true;
      };
      description = "Systemd OnCalendar timer specification for automatic host backups.";
    };

    userTimerConfig = mkOption {
      type = types.attrsOf types.anything;
      default = {
        OnCalendar = "02:30";
        Persistent = true;
      };
      description = "Systemd OnCalendar timer specification for automatic user backups.";
    };

    pruneOpts = mkOption {
      type = types.listOf types.str;
      default = [
        "--group-by"
        "host,paths"
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];
      description = "Options passed to restic forget --prune on the primary node.";
    };

    extraBackupArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra arguments passed to restic backup.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.repository != "";
        message = "features.backup.repository must not be empty when enabled";
      }
      {
        assertion = cfg.passwordFile != null;
        message = "features.backup.passwordFile must be set when enabled";
      }
    ];

    environment.systemPackages = [pkgs.restic];

    services.restic.backups = {
      # Tier 3: Host Persistent State Backup
      host-state = {
        inherit (cfg) repository;
        inherit (cfg) passwordFile;
        inherit (cfg) environmentFile;
        inherit (cfg) timerConfig;
        inherit (cfg) paths;
        extraBackupArgs = ["--tag" "host" "--exclude-caches"] ++ cfg.extraBackupArgs;
        pruneOpts =
          if cfg.isPrimary
          then cfg.pruneOpts
          else [];
        initialize = true;
      };

      # Tier 4: User Persistent State Backup (when /persist/user is mounted)
      user-state = mkIf (cfg.backupUser && (config.fileSystems ? "/persist/user")) {
        inherit (cfg) repository;
        inherit (cfg) passwordFile;
        inherit (cfg) environmentFile;
        timerConfig = cfg.userTimerConfig;
        paths = cfg.userPaths;
        inherit (cfg) exclude;
        extraBackupArgs = ["--tag" "user" "--exclude-caches"] ++ cfg.extraBackupArgs;
        pruneOpts =
          if cfg.isPrimary
          then [
            "--group-by"
            "paths"
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 12"
          ]
          else [];
        initialize = true;
      };
    };
  };
}
