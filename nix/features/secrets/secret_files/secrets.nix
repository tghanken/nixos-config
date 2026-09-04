let
  keys = import ../keys.nix;
in {
  "encrypted/github_pat.age".publicKeys = keys.all;
  "encrypted/nix_store_signing_key.age".publicKeys = keys.all;
  "encrypted/tailscale_key.age".publicKeys = keys.all;
  "encrypted/github_runner_tghanken.age".publicKeys = [keys.hercules] ++ keys.tghanken;
  "encrypted/github_runner_actionable_work.age".publicKeys = [keys.hercules] ++ keys.tghanken;
  "encrypted/niks3_upload_token.age".publicKeys = [keys.hercules] ++ keys.tghanken;
}
