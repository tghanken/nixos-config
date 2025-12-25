{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lmstudio
  ];
  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd
  ];
}
