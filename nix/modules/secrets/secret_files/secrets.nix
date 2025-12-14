let
  keys = import ../keys.nix;
in {
  "encrypted/github_pat.age".publicKeys = keys.all;
  "encrypted/netbird_taylor_client.age".publicKeys = keys.clients ++ keys.tghanken;
  "encrypted/netbird_local_server.age".publicKeys = keys.local-servers ++ keys.tghanken;
  "encrypted/netbird_remote_server.age".publicKeys = keys.remote-servers ++ keys.tghanken;
  "encrypted/nix_store_signing_key.age".publicKeys = keys.all;
  "encrypted/tailscale_key.age".publicKeys = keys.all;
}
