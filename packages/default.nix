{
  pkgs,
  nixpkgs,
}: let
  inherit (pkgs) callPackage python3Packages;
in {
  windsurf = callPackage ./windsurf.nix {inherit nixpkgs;};
}
