{inputs, ...}: let
  encrypted_path = ./secret_files/encrypted;
in {
  imports = [
    inputs.agenix.nixosModules.default
  ];

  config.age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  config.age.secrets = {
    github_pat.file = encrypted_path + "/github_pat.age";
    tailscale_key.file = encrypted_path + "/tailscale_key.age";
  };
}
