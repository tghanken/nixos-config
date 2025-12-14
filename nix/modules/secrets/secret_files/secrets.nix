let
  keys = import ../keys.nix;
in {
  "encrypted/nix_store_signing_key.age".publicKeys = keys.all;
  "encrypted/github_pat.age".publicKeys = keys.all;
  "encrypted/tailscale_key.age".publicKeys = keys.all;
}
