# Common profile - Applied to all activated hosts (adds secrets)
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./install.nix
    inputs.agenix.nixosModules.default
    ../../secrets/mod.nix
    ../common/builders/build_server.nix
    ../common/networking/networking.nix
    ../common/utils/utils.nix
  ];
}
