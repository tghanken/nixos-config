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

    paths = mkOption {
      type = types.listOf types.str;
      default = ["/persist"];
      description = "List of directories to back up.";
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
      ];
      description = "List of glob patterns to exclude from backups.";
    };

    timerConfig = mkOption {
      type = types.attrsOf types.anything;
      default = {
        OnCalendar = "02:00";
        Persistent = true;
      };
      description = "Systemd OnCalendar timer specification for automatic backups.";
    };

    pruneOpts = mkOption {
      type = types.listOf types.str;
      default = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];
      description = "Options passed to restic forget --prune.";
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

    services.restic.backups.system = {
      inherit (cfg) repository;
      inherit (cfg) passwordFile;
      inherit (cfg) environmentFile;
      inherit (cfg) paths;
      inherit (cfg) exclude;
      inherit (cfg) timerConfig;
      inherit (cfg) pruneOpts;
      inherit (cfg) extraBackupArgs;
      initialize = true;
    };
  };
}
