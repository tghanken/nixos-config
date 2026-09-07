{
  self,
  inputs,
  ...
}: let
  hostsLib = import ../lib/hosts.nix {inherit self inputs;};
  colmenaLib = import ../lib/colmena.nix {inherit self inputs;};
  hosts = hostsLib.loadHosts ./.;
in {
  flake = {
    nixosConfigurations = hostsLib.mkHosts hosts;
    colmena = colmenaLib.mkHive hosts;
  };
}
