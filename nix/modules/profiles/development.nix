# Used for a client device focused on development tasks
{flake, ...}: {
  imports = [
    flake.modules.profiles.shared-client
    flake.modules.utils.docker
  ];
}
