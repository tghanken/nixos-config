{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.services.resticRestServer;
in {
  options.services.resticRestServer = {
    enable = mkEnableOption "Self-hosted Restic REST backup server";

    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0:8000";
      description = "Address and port on which the rest-server listens.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/restic-rest-server";
      description = "Data directory for storing restic repositories.";
    };

    appendOnly = mkOption {
      type = types.bool;
      default = true;
      description = "Enable append-only mode (prevents client deletion of existing snapshots).";
    };

    prometheus = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Prometheus metrics endpoint.";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional CLI flags passed to rest-server.";
    };
  };

  config = mkIf cfg.enable {
    services.restic.rest-server = {
      enable = true;
      inherit (cfg) listenAddress;
      inherit (cfg) dataDir;
      inherit (cfg) appendOnly;
      inherit (cfg) prometheus;
      inherit (cfg) extraFlags;
    };

    # Ensure repository directory is persisted if impermanence is active
    environment.persistence."/persist" = mkIf (config.services ? impermanence && config.services.impermanence.enable) {
      directories = [
        cfg.dataDir
      ];
    };
  };
}
