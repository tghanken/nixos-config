{
  description = "NixOS configuration for home devices";

  inputs = {
    # Core Inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    blueprint = {
      url = "github:numtide/blueprint";
      inputs.nixpkgs.follows = "nixpkgs";
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
      url = "github:nix-community/home-manager/release-25.05";
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

  outputs = inputs: inputs.blueprint { inherit inputs; };
}
