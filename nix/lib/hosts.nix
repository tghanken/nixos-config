{
  self,
  inputs,
  lib ? inputs.nixpkgs.lib,
  ...
}: let
  /*
  Constructs the list of NixOS modules for a given host configuration.
  */
  mkHostModules = {
    hostName,
    hostModule,
    hostPubkey ? null,
    users ? ["tghanken"],
    ...
  }: let
    facterPath = hostModule + "/facter.json";
    legacyDiskConfig = hostModule + "/disk-config.nix";
    hostPubkeyPath = hostModule + "/key.pub";

    # Host public key for agenix-rekey
    resolvedHostPubkey =
      if hostPubkey != null
      then hostPubkey
      else if builtins.pathExists hostPubkeyPath
      then lib.strings.trim (builtins.readFile hostPubkeyPath)
      else null;

    rekeyModule = lib.optionalAttrs (resolvedHostPubkey != null) {
      age.rekey.hostPubkey = resolvedHostPubkey;
    };

    # Legacy disk configuration fallback
    legacyDiskoModule = lib.optionalAttrs (builtins.pathExists legacyDiskConfig) {
      disko.devices = import legacyDiskConfig;
    };

    # User modules
    userModules = map (user: ../users/${user}.nix) users;

    # Automated facter module
    facterModule = lib.optionalAttrs (builtins.pathExists facterPath) {
      config.facter.reportPath = facterPath;
    };

    # Automated hostname
    baseHostModule = {
      networking.hostName = hostName;
    };
  in
    [
      inputs.disko.nixosModules.disko
      inputs.nixos-facter-modules.nixosModules.facter
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit inputs;
          flake = self;
          inherit self;
        };
      }
      baseHostModule
      facterModule
      legacyDiskoModule
      rekeyModule
    ]
    ++ userModules
    ++ [hostModule];

  /*
  Instantiates a NixOS system configuration using mkHostModules.
  */
  mkHost = args:
    lib.nixosSystem {
      system = args.system or "x86_64-linux";
      specialArgs = {
        inherit inputs;
        inherit (args) hostName;
        flake = self;
        inherit self;
      };
      modules = mkHostModules args;
    };

  /*
  Maps mkHost over an attribute set of host argument definitions.
  */
  mkHosts = hosts: lib.mapAttrs (_name: mkHost) hosts;

  /*
  Discovers host subdirectories in `dir` containing a `default.nix`.
  Automatically derives:
  - hostName from directory name
  - hostModule from directory path

  Usage:
    loadHosts ./.
    loadHosts { dir = ./.; overrides = { ... }; }
  */
  loadHosts = args: let
    dir =
      if builtins.isAttrs args && args ? dir
      then args.dir
      else args;
    overrides =
      if builtins.isAttrs args && args ? overrides
      then args.overrides
      else {};

    entries = builtins.readDir dir;
    hostDirs =
      lib.filterAttrs (
        name: type:
          type == "directory" && builtins.pathExists (dir + "/${name}/default.nix")
      )
      entries;

    parseHost = name: _:
      {
        hostName = name;
        hostModule = dir + "/${name}";
      }
      // (overrides.${name} or {});
  in
    lib.mapAttrs parseHost hostDirs;
in {
  inherit mkHostModules mkHost mkHosts loadHosts;
}
