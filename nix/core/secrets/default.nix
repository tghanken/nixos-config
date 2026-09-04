{
  inputs,
  self,
  config,
  lib,
  ...
}: let
  keysLib = import ../../lib/keys.nix {inherit lib;};

  # Admin users whose keys are added as secret decode keys
  adminUsers = ["tghanken"];
  adminKeys = lib.concatMap keysLib.readUserKeys adminUsers;
in {
  imports = [
    inputs.agenix.nixosModules.default
    inputs.agenix-rekey.nixosModules.default
  ];

  config.age = {
    identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

    rekey = {
      storageMode = "local";
      localStorageDir = self + "/nix/core/secrets/rekeyed/${config.networking.hostName}";
      masterIdentities = [
        "/home/tghanken/.ssh/id_ed25519"
      ];
      extraEncryptionPubkeys = adminKeys;
    };
  };
}
