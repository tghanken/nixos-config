{
  localFlake,
  pkgs,
  config,
  self,
  system,
  ...
}: let
  local = localFlake.self.packages.${system};
in {
  environment.systemPackages = with pkgs; [
    local.windsurf
  ];
}
