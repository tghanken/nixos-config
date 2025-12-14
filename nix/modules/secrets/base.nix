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
    netbird_taylor_client.file = encrypted_path + "/netbird_taylor_client.age";
    netbird_local_server.file = encrypted_path + "/netbird_local_server.age";
    netbird_remote_server.file = encrypted_path + "/netbird_remote_server.age";
    nix_store_signing_key.file = encrypted_path + "/nix_store_signing_key.age";
    tailscale_key.file = encrypted_path + "/tailscale_key.age";
  };
}
