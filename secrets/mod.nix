{
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  # Secrets
  age.secrets = {
    github_pat.file = ./keys/github_pat.age;
    nix_store_signing_key.file = ./keys/nix_store_signing_key.age;
    tailscale_key.file = ./keys/tailscale_key.age;
  };
}
