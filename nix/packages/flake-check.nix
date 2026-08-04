{
  pkgs,
  inputs,
  ...
}: let
  flakeSrc = pkgs.lib.cleanSource inputs.self;
in
  import ../lib/flake-check-tier.nix {
    inherit pkgs flakeSrc;
    name = "flake-check";
  }
