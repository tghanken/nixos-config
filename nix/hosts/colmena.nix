{
  self,
  inputs,
  hosts,
  mkHostModules,
}: let
  lib = inputs.nixpkgs.lib;

  mkColmenaNode = {
    hostName,
    diskRole ? null,
    targetHost ? null,
    targetIp ? null,
    tags ? [],
    ...
  } @ args: let
    isWorkstation = diskRole == "workstation";
    roleTag =
      if isWorkstation
      then "workstation"
      else "server";

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
      tags =
        [roleTag]
        ++ (lib.optional (diskRole != null) diskRole)
        ++ tags;
    };
    imports = mkHostModules args;
  };

  nodes = lib.mapAttrs (_name: args: mkColmenaNode args) hosts;
in
  {
    meta = {
      nixpkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
      };
      specialArgs = {
        inherit inputs;
        flake = self;
        self = self;
      };
    };
  }
  // nodes
