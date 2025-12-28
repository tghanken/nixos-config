# Used for a server in a location controlled by me
{
  flake,
  config,
  ...
}:
with config; {
  imports = [
    flake.modules.profiles.shared-server
  ];

  age.secrets.netbird_key.file = ../secrets/secret_files/encrypted/netbird_local_server.age;
  services.netbird_user.auth_key_path = age.secrets.netbird_key.path;
}
