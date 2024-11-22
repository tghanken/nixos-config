{
  config,
  lib,
  pkgs,
  ...
}: {
  services.nix-serve = {
    enable = true;
    package = pkgs.nix-serve-ng;
    secretKeyFile = config.age.secrets.nix_store_signing_key.path;
    port = 16893;
    openFirewall = true;
  };
}
