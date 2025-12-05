# CI checks
{
  pkgs,
  lib,
  self,
  ...
}: let
  fs = lib.fileset;
  sourceFiles = fs.unions [
    (fs.fileFilter (file: file.hasExt "nix") self)
  ];
in {
  nix-fmt-check = pkgs.stdenv.mkDerivation {
    name = "nix-fmt-check";
    src = fs.toSource {
      root = self;
      fileset = sourceFiles;
    };
    installPhase = ''
      ${pkgs.alejandra}/bin/alejandra -c .
      touch $out
    '';
  };
}
