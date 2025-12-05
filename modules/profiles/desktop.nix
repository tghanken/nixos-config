# Desktop profile - Applied to desktop hosts (adds home-manager)
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./common.nix
    inputs.home-manager.nixosModules.home-manager
    ../desktop/desktop.nix
    ../users/users.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.tghanken = import ../users/tghanken/home-manager.nix;
  };
}
