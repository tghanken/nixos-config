{ inputs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.tghanken = import ../users/tghanken/home-manager.nix;
      };
    }
  ];
}
