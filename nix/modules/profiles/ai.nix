# Serve AI Models
{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    lmstudio
  ];
  hardware.graphics.extraPackages = with pkgs; [
    # Currently ai profile is only used on amd. If I get a nvidia device, refactor this.
    rocmPackages.clr.icd
  ];

  # Docker is required for Hermes Agent container mode
  virtualisation.docker = {
    enable = true;
    storageDriver = "zfs";
    autoPrune = {
      enable = true;
      flags = [];
    };
  };

  # users.users.ollama = {
  #   isNormalUser = false;
  #   description = "Ollama";
  # };
  # services.ollama = {
  #   enable = true;
  #   home = "/mnt/ollama";
  #   user = "ollama";
  # };
}
