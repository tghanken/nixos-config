# Serve AI Models
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lmstudio
  ];
  hardware.graphics.extraPackages = with pkgs; [
    # Currently ai profile is only used on amd. If I get a nvidia device, refactor this.
    rocmPackages.clr.icd
  ];

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
