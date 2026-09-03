{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.customRestic;
in {
  options.services.customRestic = {
    enable = mkEnableOption "Declarative Restic backup service";
    repository = mkOption {
      type = types.str;
      default = "";
      description = "Restic repository URL (e.g. sftp:user@host:/path or s3:s3.amazonaws.com/bucket)";
    };
    passwordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to file containing the repository password";
    };
    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to environment file containing S3/B2 credentials (e.g. AWS_ACCESS_KEY_ID)";
    };
    paths = mkOption {
      type = types.listOf types.str;
      default = ["/persist"];
      description = "List of directories to back up";
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
      description = "List of glob patterns to exclude from backups";
    };
    timerConfig = mkOption {
      type = types.attrsOf types.anything;
      default = {
        OnCalendar = "02:00";
        Persistent = true;
      };
      description = "Systemd OnCalendar timer specification for automatic backups";
    };
    pruneOpts = mkOption {
      type = types.listOf types.str;
      default = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];
      description = "Options passed to restic forget --prune";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.repository != "";
        message = "services.customRestic.repository must not be empty when enabled";
      }
      {
        assertion = cfg.passwordFile != null;
        message = "services.customRestic.passwordFile must be set when enabled";
      }
    ];

    environment.systemPackages = [pkgs.restic];

    services.restic.backups.system = {
      repository = cfg.repository;
      passwordFile = cfg.passwordFile;
      environmentFile = cfg.environmentFile;
      paths = cfg.paths;
      exclude = cfg.exclude;
      timerConfig = cfg.timerConfig;
      pruneOpts = cfg.pruneOpts;
      initialize = true;
    };
  };
}
