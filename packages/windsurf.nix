{
  lib,
  stdenv,
  nixpkgs,
  callPackage,
  fetchurl,
  nixosTests,
  commandLineArgs ? "",
  useVSCodeRipgrep ? stdenv.hostPlatform.isDarwin,
}:
# https://windsurf-stable.codeium.com/api/update/linux-x64/stable/latest
let
  version = "1.2.6"; # "windsurfVersion"
  hash = "d08b8ea13d580d24be204c76e5dd1651d7234cd2"; # "version"
in
  callPackage "${nixpkgs}/pkgs/applications/editors/vscode/generic.nix" rec {
    inherit commandLineArgs useVSCodeRipgrep version;

    pname = "windsurf";

    executableName = "windsurf";
    longName = "Windsurf";
    shortName = "windsurf";

    src = fetchurl {
      url = "https://windsurf-stable.codeiumdata.com/linux-x64/stable/${hash}/Windsurf-linux-x64-${version}.tar.gz";
      hash = "sha256-rXHrArkwLUzxQTwKg3Y/Rf5FXlvnTunhR3vqLoWgLKo=";
    };

    sourceRoot = "Windsurf";

    tests = nixosTests.vscodium;

    updateScript = "nil";

    meta = {
      description = "The first agentic IDE, and then some";
    };
  }
