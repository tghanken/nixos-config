{inputs, ...}: let
  encrypted_path = ./secret_files/encrypted;
in {
  imports = [
    inputs.agenix.nixosModules.default
  ];

  config.age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  # Secrets
  config.age.secrets = {
    github_pat.file = encrypted_path + "/github_pat.age";
    nix_store_signing_key.file = encrypted_path + "/nix_store_signing_key.age";
    tailscale_key.file = encrypted_path + "/tailscale_key.age";
  };
}
