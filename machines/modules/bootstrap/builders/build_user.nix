{
  users.users.nixbuilder = {
    isNormalUser = true;
    description = "nixbuilder";
    group = "nixbuilder";
  };
  users.groups.nixbuilder = {};
  nix.settings.trusted-users = ["nixbuilder"];
}
