/*
GitHub Actions self-hosted runners: one NixOS container per GitHub owner.

Each owner gets its own container and agenix PAT so tokens are not shared
across personal vs org boundaries. See github-runner.md for auth setup.

  just es github_runner_<owner>

Token file must be exactly one line with no trailing newline.
*/
top @ {
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) types mkOption mkIf mkMerge listToAttrs nameValuePair optionalAttrs optionals unique groupBy mapAttrsToList;
  cfg = config.services.github-runner-containers;

  runnerUser = "github-runner";
  encryptedPath = ../secrets/secret_files/encrypted;

  sanitizeSecret = s: lib.replaceStrings ["-" "."] ["_" "_"] s;
  # nixos-containers disallow underscores in names
  sanitizeContainer = s: lib.replaceStrings ["_" "."] ["-" "-"] s;
  secretNameForOwner = owner: "github_runner_${sanitizeSecret owner}";
  containerNameForOwner = owner: "github-runners-${sanitizeContainer owner}";
  runnerServiceName = runner: "${sanitizeSecret runner.owner}-${sanitizeSecret runner.repo}";
  runnerUrl = runner: "https://github.com/${runner.owner}/${runner.repo}";

  owners = unique (map (r: r.owner) cfg.runners);
  runnersByOwner = groupBy (r: r.owner) cfg.runners;

  niks3Substituter = "https://niks3.actionable-internal.work";
  niks3PublicKey = "actionable-niks3:A3EpGS6+W9zj0r6tY3KPoODoBRELq70j+dkbhhgi7aQ=";
  niks3UploadSecret = "niks3_upload_token";

  hostDockerGid = config.users.groups.docker.gid or null;
  hostName = config.networking.hostName;

  userModule = {
    users.users.${runnerUser} = {
      isSystemUser = true;
      group = runnerUser;
      home = "/var/lib/github-runner";
      createHome = true;
      description = "GitHub Actions runner";
      extraGroups = optionals cfg.dockerSocket ["docker"];
    };
    users.groups.${runnerUser} = {};
  };

  runnerSubmodule = types.submodule {
    options = {
      owner = mkOption {
        type = types.str;
        description = "GitHub owner (user or organization).";
        example = "tghanken";
      };
      repo = mkOption {
        type = types.str;
        description = "Repository name.";
        example = "nixos-config";
      };
      extraLabels = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Extra labels for this runner (merged with module defaults).";
      };
    };
  };

  mkOwnerContainer = owner: runners: let
    tokenFile = config.age.secrets.${secretNameForOwner owner}.path;
  in {
    autoStart = true;
    ephemeral = false;
    privateUsers = "no";

    bindMounts =
      {
        ${tokenFile} = {
          hostPath = tokenFile;
          isReadOnly = true;
        };
      }
      // optionalAttrs cfg.dockerSocket {
        "/var/run/docker.sock" = {
          hostPath = "/var/run/docker.sock";
          isReadOnly = false;
        };
      }
      // optionalAttrs cfg.shareNixStore {
        "/nix/store" = {
          hostPath = "/nix/store";
          isReadOnly = true;
        };
        # Read-only so the container cannot replace the host's daemon socket.
        "/nix/var/nix/daemon-socket" = {
          hostPath = "/nix/var/nix/daemon-socket";
          isReadOnly = true;
        };
      };

    config = {pkgs, ...}: {
      imports = [userModule];

      system.stateVersion = top.config.system.stateVersion;

      networking.hostName = containerNameForOwner owner;

      programs.nix-ld.enable = true;

      # Never run a container-local nix-daemon against the shared host socket —
      # that replaces the host socket and breaks Nix for everyone on the machine.
      nix.enable = !cfg.shareNixStore;
      environment.systemPackages = optionals cfg.shareNixStore [pkgs.nix];
      environment.variables = optionalAttrs cfg.shareNixStore {
        NIX_REMOTE = "daemon";
      };

      nix.settings = mkMerge [
        {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [runnerUser];
          keep-outputs = true;
          keep-derivations = true;
        }
        (mkIf cfg.niks3.enable {
          substituters = [cfg.niks3.substituter];
          trusted-public-keys = [cfg.niks3.publicKey];
        })
      ];

      users.groups.docker = mkIf cfg.dockerSocket (
        mkIf (hostDockerGid != null) {
          gid = hostDockerGid;
        }
      );

      services.github-runners = listToAttrs (
        map (runner: let
          labels =
            cfg.extraLabels
            ++ [hostName]
            ++ runner.extraLabels;
        in
          nameValuePair (runnerServiceName runner) {
            enable = true;
            name = "${runner.owner}-${runner.repo}-${hostName}";
            url = runnerUrl runner;
            extraPackages = cfg.extraPackages;
            user = runnerUser;
            group = runnerUser;
            tokenFile = tokenFile;
            replace = true;
            extraLabels = labels;
            extraEnvironment = optionalAttrs cfg.shareNixStore {
              NIX_REMOTE = "daemon";
            };
            serviceOverrides = {
              PrivateUsers = false;
              RestrictNamespaces = false;
              SupplementaryGroups = optionals cfg.dockerSocket ["docker"];
              BindPaths =
                (optionals cfg.dockerSocket ["/var/run/docker.sock"])
                ++ (optionals cfg.shareNixStore ["/nix/var/nix/daemon-socket"]);
              BindReadOnlyPaths = optionals cfg.shareNixStore ["/nix/store"];
            };
          })
        runners
      );
    };
  };
in {
  imports = [inputs.niks3.nixosModules.niks3-auto-upload];

  options.services.github-runner-containers = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Run GitHub Actions self-hosted runners in per-owner NixOS containers.";
    };

    runners = mkOption {
      type = types.listOf runnerSubmodule;
      default = [];
      description = ''
        Runners to register. Grouped by `owner` into one container each.
        Each owner needs encrypted/github_runner_<owner>.age
        (hyphens/dots become underscores). See github-runner.md.
      '';
      example = [
        {
          owner = "tghanken";
          repo = "nixos-config";
        }
        {
          owner = "actionable-work";
          repo = "actionable";
        }
      ];
    };

    dockerSocket = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Bind-mount the host Docker socket into runner containers so workflows
        can use `container:` jobs. Weakens isolation: jobs can control the
        host Docker daemon.
      '';
    };

    shareNixStore = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Bind-mount the host `/nix/store` (read-only) and nix-daemon socket
        (read-only) into each container, disable the in-container nix-daemon,
        and set `NIX_REMOTE=daemon` so builds reuse the host store and daemon.
      '';
    };

    extraLabels = mkOption {
      type = types.listOf types.str;
      default = ["nixos"];
      description = "Extra runner labels applied to every runner (plus hostname).";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        git
        which
        coreutils
        docker
        cachix
      ];
      description = "Packages available to GitHub Actions jobs on the runner.";
    };

    niks3 = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Add the actionable niks3 binary cache as a pull-only substituter.";
      };
      substituter = mkOption {
        type = types.str;
        default = niks3Substituter;
        description = "niks3 substituter URL.";
      };
      publicKey = mkOption {
        type = types.str;
        default = niks3PublicKey;
        description = "niks3 trusted public key.";
      };
      uploader = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Upload runner builds to niks3 via the niks3-hook auto-upload daemon
            (post-build-hook on the host nix-daemon). Requires
            encrypted/niks3_upload_token.age and shareNixStore (see github-runner.md).
          '';
        };
        server = mkOption {
          type = types.str;
          default = niks3Substituter;
          description = "niks3 server URL for the auto-upload daemon.";
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    userModule

    {
      assertions = [
        {
          assertion = cfg.runners != [];
          message = "services.github-runner-containers.runners must be non-empty when enable = true";
        }
        {
          assertion = !cfg.dockerSocket || config.virtualisation.docker.enable;
          message = "services.github-runner-containers.dockerSocket requires virtualisation.docker.enable";
        }
        {
          assertion = !cfg.niks3.uploader.enable || cfg.shareNixStore;
          message = "services.github-runner-containers.niks3.uploader requires shareNixStore (host nix-daemon post-build-hook)";
        }
      ];

      # Host daemon performs substitutions when shareNixStore is on.
      # trusted-users implies allowed; do not set allowed-users (would risk
      # narrowing access if merged incorrectly).
      nix.settings = mkMerge [
        {
          trusted-users = [runnerUser];
        }
        (mkIf cfg.niks3.enable {
          substituters = [cfg.niks3.substituter];
          trusted-public-keys = [cfg.niks3.publicKey];
        })
      ];

      services.niks3-auto-upload = mkIf cfg.niks3.uploader.enable {
        enable = true;
        serverUrl = cfg.niks3.uploader.server;
        authTokenFile = config.age.secrets.${niks3UploadSecret}.path;
      };

      age.secrets =
        listToAttrs (
          map (owner:
            nameValuePair (secretNameForOwner owner) {
              file = "${encryptedPath}/${secretNameForOwner owner}.age";
              mode = "0440";
            })
          owners
        )
        // optionalAttrs cfg.niks3.uploader.enable {
          ${niks3UploadSecret} = {
            file = "${encryptedPath}/${niks3UploadSecret}.age";
            mode = "0440";
          };
        };

      containers = listToAttrs (
        mapAttrsToList (owner: runners:
          nameValuePair (containerNameForOwner owner) (mkOwnerContainer owner runners))
        runnersByOwner
      );
    }
  ]);
}
