{lib, ...}: rec {
  /*
  Reads an OpenSSH authorized_keys file and returns a list of trimmed key strings,
  ignoring empty lines and comment lines starting with #.
  */
  readKeyFile = path:
    if builtins.pathExists path
    then
      lib.pipe path [
        builtins.readFile
        (lib.strings.splitString "\n")
        (builtins.filter (line: line != "" && !(lib.hasPrefix "#" line)))
        (map lib.strings.trim)
      ]
    else [];

  /*
  Reads the keys file for a given user from nix/users/<user>.keys.
  */
  readUserKeys = user: readKeyFile (../users + "/${user}.keys");
}
