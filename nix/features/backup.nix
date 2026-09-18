{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.features.backup;
  secretsDir = ../core/secrets/secret_files;
  hasResticPassword = builtins.pathExists (secretsDir + "/restic_password.age");
  hasResticR2Env = builtins.pathExists (secretsDir + "/restic_r2_env.age");

  hasTier3 =
    (config.environment.persistence ? "/persist/host")
    && (
      (config.environment.persistence."/persist/host".directories or [])
      != []
      || (config.environment.persistence."/persist/host".files or []) != []
    );

  hasTier4 =
    (config.environment.persistence ? "/persist/user")
    && (
      (config.environment.persistence."/persist/user".directories or [])
      != []
      || (config.environment.persistence."/persist/user".files or []) != []
      || (config.environment.persistence."/persist/user".users or {}) != {}
    );

  hasTier3Or4 = hasTier3 || hasTier4;
in {
  options.features.backup = {
    enable = mkEnableOption "Declarative Restic backup client";

    requireBackup = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enforce mandatory backup assertion when Tier 3/4 storage is used.";
    };

    backend = mkOption {
      type = types.enum ["r2" "rest" "custom"];
      default = "r2";
      description = "Backup target type ('r2' for Cloudflare S3, 'rest' for self-hosted REST server, 'custom' for arbitrary repository URI).";
    };

    r2 = {
      accountId = mkOption {
        type = types.str;
        default = "";
        description = "Cloudflare account ID for R2 storage.";
      };

      bucket = mkOption {
        type = types.str;
        default = "";
        description = "Cloudflare R2 bucket name.";
      };
    };

    repository = mkOption {
      type = types.str;
      default =
        if cfg.backend == "r2" && cfg.r2.accountId != "" && cfg.r2.bucket != ""
        then "s3:https://${cfg.r2.accountId}.r2.cloudflarestorage.com/${cfg.r2.bucket}/nixos"
        else "";
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
        RandomizedDelaySec = "45min";
      };
      description = "Systemd OnCalendar timer specification for automatic host backups.";
    };

    userTimerConfig = mkOption {
      type = types.attrsOf types.anything;
      default = {
        OnCalendar = "02:30";
        Persistent = true;
        RandomizedDelaySec = "45min";
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

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.requireBackup && hasTier3Or4) || cfg.enable;
          message = ''
            Host '${config.networking.hostName}' includes modules declaring Tier 3 (/persist/host) or Tier 4 (/persist/user) persistent storage, so features.backup must be enabled!
            To explicitly disable backups for this host, configure:
              features.backup.requireBackup = false;
              features.backup.enable = false;
          '';
        }
        {
          assertion = !cfg.enable || hasResticPassword;
          message = ''
            Host '${config.networking.hostName}' has features.backup enabled (required by Tier 3/4 storage), but the repository encryption password secret is missing!
            Required secret file:
              - nix/core/secrets/secret_files/restic_password.age
            Please create the secret before building:
              just edit-secret restic_password
              just rekey-secrets
          '';
        }
        {
          assertion = !cfg.enable || cfg.backend != "r2" || hasResticR2Env;
          message = ''
            Host '${config.networking.hostName}' has features.backup enabled with backend = 'r2', but Cloudflare R2 credentials secret is missing!
            Required secret file:
              - nix/core/secrets/secret_files/restic_r2_env.age
            Please create the secret with AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY:
              just edit-secret restic_r2_env
              just rekey-secrets
          '';
        }
      ];
    }
    (mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.repository != "";
          message = ''
            Host '${config.networking.hostName}' has features.backup enabled, but features.backup.repository is empty!
            Configure either:
              features.backup.repository = "s3:https://<account>.r2.cloudflarestorage.com/<bucket>/nixos";
            or:
              features.backup.r2.accountId = "<account-id>";
              features.backup.r2.bucket = "<bucket-name>";
          '';
        }
        {
          assertion = !(lib.hasInfix "<account>" cfg.repository || lib.hasInfix "<bucket>" cfg.repository);
          message = "Host '${config.networking.hostName}' has placeholder tokens ('<account>' or '<bucket>') in features.backup.repository ('${cfg.repository}')!";
        }
        {
          assertion = cfg.backend != "r2" || lib.hasPrefix "s3:" cfg.repository;
          message = "Host '${config.networking.hostName}' has features.backup.backend = 'r2', but features.backup.repository does not start with 's3:' ('${cfg.repository}')!";
        }
        {
          assertion = cfg.backend != "r2" || cfg.environmentFile != null;
          message = ''
            Host '${config.networking.hostName}' has features.backup.backend = 'r2', but features.backup.environmentFile is null!
            Cloudflare R2 requires AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.
            Create the secret with:
              just edit-secret restic_r2_env
              just rekey-secrets
          '';
        }
        {
          assertion = cfg.passwordFile != null;
          message = ''
            Host '${config.networking.hostName}' has features.backup enabled, but features.backup.passwordFile is null!
            Create the encryption password secret with:
              just edit-secret restic_password
              just rekey-secrets
          '';
        }
      ];

      age.secrets = {
        restic_password = mkIf hasResticPassword {
          rekeyFile = secretsDir + "/restic_password.age";
        };
        restic_r2_env = mkIf hasResticR2Env {
          rekeyFile = secretsDir + "/restic_r2_env.age";
        };
      };

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
              "host,paths"
              "--keep-daily 7"
              "--keep-weekly 4"
              "--keep-monthly 12"
            ]
            else [];
          initialize = true;
        };
      };
    })
  ];
}
