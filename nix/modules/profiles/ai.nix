# Serve AI Models
{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages =
    [
      pkgs.lmstudio
    ]
    ++ (with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      antigravity-cli
      opencode
      cursor-agent
      jules
      kilocode-cli
      pi
      hermes-agent
      hermes-desktop
      openspec
      openspecui
      lean-ctx
      qmd
      nono
    ]);
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
