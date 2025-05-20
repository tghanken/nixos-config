{
  description = "NixOS configuration for home devices";

  inputs = {
    # Core Inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    nix-systems = {
      url = "github:nix-systems/default";
    };

    # NixOs Inputs
    agenix = {
      url = "github:ryantm/agenix";
      # TODO: Enable once darwin is setup
      inputs.darwin.follows = "";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "nix-systems";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };
  };

  outputs = inputs @ {
    # Core Inputs
    nixpkgs,
    flake-parts,
    # NixOs Inputs
    agenix,
    disko,
    home-manager,
    nixos-generators,
    nixos-hardware,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} ({
      withSystem,
      flake-parts-lib,
      ...
    }: let
      inherit (flake-parts-lib) importApply;
      flakeModules.clusters = importApply ./clusters/clusters.nix {inherit withSystem;};
      flakeModules.machines = importApply ./machines/machines.nix {inherit withSystem;};
    in {
      imports = [
        flakeModules.clusters
        flakeModules.machines
      ];

      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];

      perSystem = {
        pkgs,
        system,
        lib,
        ...
      }: {
        checks = let
          fs = lib.fileset;
          sourceFiles = fs.unions [
            (fs.fileFilter (file: file.hasExt "nix") ./.)
          ];
        in {
          nix-fmt-check = pkgs.stdenv.mkDerivation {
            name = "nix-fmt-check";
            src = fs.toSource {
              root = ./.;
              fileset = sourceFiles;
            };
            installPhase = ''
              ${pkgs.alejandra}/bin/alejandra -c .
              touch $out
            '';
          };
        };
        formatter = pkgs.alejandra;
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            inputs.agenix.packages.${system}.default
          ];
        };

        packages = import ./packages {
          inherit nixpkgs;
          pkgs = nixpkgs.legacyPackages.${system};
        };
      };
    });
}
