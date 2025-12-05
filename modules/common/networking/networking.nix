{config, ...}:
with config; {
  services.tailscale_user.auth_key_path = age.secrets."tailscale_key".path;
  services.cloudflare-warp.enable = true;
}
