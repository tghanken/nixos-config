# Serve AI Models
{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages =
    [
      pkgs.lmstudio
      pkgs.ripgrep
      pkgs.dolt
    ]
    ++ (with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      antigravity-cli
      opencode
      cursor-agent
      codex
      jules
      kilocode-cli
      omp
      gascity
      # beads
      herdr
      gitbutler
      hermes-agent
      hermes-desktop
      openspec
      openspecui
      qmd
      nono
    ]);
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
