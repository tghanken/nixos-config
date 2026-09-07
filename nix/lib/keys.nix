{lib, ...}: let
  /*
  Normalizes an OpenSSH public key string by returning only "<type> <base64>",
  stripping any trailing comments and extra whitespace.
  */
  normalizePubkey = keyStr: let
    parts = builtins.filter (s: s != "") (lib.strings.splitString " " (lib.strings.trim keyStr));
  in
    if builtins.length parts >= 2
    then "${builtins.elemAt parts 0} ${builtins.elemAt parts 1}"
    else lib.strings.trim keyStr;

  /*
  Reads an OpenSSH authorized_keys file and returns a list of trimmed, normalized key strings,
  ignoring empty lines and comment lines starting with #.
  */
  readKeyFile = path:
    if builtins.pathExists path
    then
      lib.pipe path [
        builtins.readFile
        (lib.strings.splitString "\n")
        (builtins.filter (line: line != "" && !(lib.hasPrefix "#" line)))
        (map normalizePubkey)
      ]
    else [];

  /*
  Reads the keys file for a given user from nix/users/<user>.keys.
  */
  readUserKeys = user: readKeyFile (../users + "/${user}.keys");

  /*
  Reusable POSIX/Bash shell helper functions for key normalization and verification.
  Used consistently across ingest-host-keys, reimage-host, and deployment tools.
  */
  shellHelpers = ''
    normalize_pubkey() {
      if [ $# -gt 0 ] && [ "$1" != "-" ]; then
        awk '{print $1, $2}' "$1"
      else
        awk '{print $1, $2}'
      fi
    }

    derive_pubkey() {
      ssh-keygen -y -f "$1" 2>/dev/null | normalize_pubkey
    }

    keys_match() {
      local priv_file="$1"
      local pub_file="$2"
      local derived expected
      derived=$(derive_pubkey "$priv_file")
      expected=$(normalize_pubkey "$pub_file")
      [ -n "$derived" ] && [ -n "$expected" ] && [ "$derived" = "$expected" ]
    }
  '';
in {
  inherit normalizePubkey readKeyFile readUserKeys shellHelpers;
}
