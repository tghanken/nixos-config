{
  self,
  inputs,
  lib ? inputs.nixpkgs.lib,
  hostsLib ? import ./hosts.nix {inherit self inputs lib;},
  ...
}: let
  /*
  Builds a Colmena node configuration from host arguments.
  */
  mkColmenaNode = {
    hostName,
    targetHost ? null,
    targetIp ? null,
    tags ? [],
    ...
  } @ args: let
    # Support fallback resolution: environment variable override, targetHost, targetIp, or hostName
    resolvedTarget = let
      envTarget = builtins.getEnv "TARGET_HOST_${hostName}";
    in
      if envTarget != ""
      then envTarget
      else if targetHost != null
      then targetHost
      else if targetIp != null
      then targetIp
      else hostName;
  in {
    deployment = {
      targetHost = resolvedTarget;
      targetUser = "root";
      buildOnTarget = false;
    };
    imports =
      (hostsLib.mkHostModules args)
      ++ [
        ({config, ...}: {
          deployment.tags = lib.unique (
            (
              if config.storage.role == "workstation"
              then ["workstation"]
              else ["server"]
            )
            ++ [config.storage.role]
            ++ tags
          );
        })
      ];
  };

  /*
  Constructs a complete Colmena hive specification from an attribute set of host definitions.
  */
  mkHive = hosts: let
    nodes = lib.mapAttrs (_name: mkColmenaNode) hosts;
  in
    {
      meta = {
        nixpkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
        };
        specialArgs = {
          inherit inputs;
          flake = self;
          inherit self;
        };
      };
    }
    // nodes;
in {
  inherit mkColmenaNode mkHive;
}
