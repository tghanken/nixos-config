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
    ]
    ++ (with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      antigravity-cli
      opencode
      codex
      jules
      herdr
    ]);
  hardware.graphics.extraPackages = with pkgs; [
    # Currently ai profile is only used on amd. If I get a nvidia device, refactor this.
    rocmPackages.clr.icd
  ];
}
