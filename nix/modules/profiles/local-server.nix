{flake, ...}: {
  imports = [
    flake.modules.profiles.server
  ];
}