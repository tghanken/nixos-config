# Server profile - Applied to server hosts
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./common.nix
    ../server/server.nix
    ../users/users.nix
  ];
}
