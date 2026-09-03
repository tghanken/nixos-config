{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./user.nix
    inputs.agenix.nixosModules.default
  ];

  config.age.secrets.nix_store_signing_key.file = ../secrets/secret_files/encrypted/nix_store_signing_key.age;

  config.services.nix-serve = {
    enable = true;
    package = pkgs.nix-serve-ng;
    secretKeyFile = config.age.secrets.nix_store_signing_key.path;
    port = 16893;
    openFirewall = true;
  };
}
