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
  version = "1.2.1"; # "windsurfVersion"
  hash = "aa53e9df956d9bc7cb1835f8eaa47768ce0e5b44"; # "version"
in
  callPackage "${nixpkgs}/pkgs/applications/editors/vscode/generic.nix" rec {
    inherit commandLineArgs useVSCodeRipgrep version;

    pname = "windsurf";

    executableName = "windsurf";
    longName = "Windsurf";
    shortName = "windsurf";

    src = fetchurl {
      url = "https://windsurf-stable.codeiumdata.com/linux-x64/stable/${hash}/Windsurf-linux-x64-${version}.tar.gz";
      hash = "sha256-dGEZQzShF5MVUZVVNFhccueVF9VqQ+/oatKRd0ZAOS0=";
    };

    sourceRoot = "Windsurf";

    tests = nixosTests.vscodium;

    updateScript = "nil";

    meta = {
      description = "The first agentic IDE, and then some";
    };
  }
