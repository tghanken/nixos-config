{
  self,
  inputs,
  ...
}: let
  mkHost = hostName: hostModule:
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
        inherit hostName;
        flake = self;
        self = self;
      };
      modules = [
        inputs.disko.nixosModules.disko
        inputs.nixos-facter-modules.nixosModules.facter
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs;
            flake = self;
            self = self;
          };
        }
        hostModule
      ];
    };
in {
  flake.nixosConfigurations = {
    hercules = mkHost "hercules" ./hercules;
    pegasus = mkHost "pegasus" ./pegasus;
    arges = mkHost "arges" ./arges;
    brontes = mkHost "brontes" ./brontes;
    steropes = mkHost "steropes" ./steropes;
    hades = mkHost "hades" ./hades;
    poseidon = mkHost "poseidon" ./poseidon;
    zeus = mkHost "zeus" ./zeus;
  };
}
