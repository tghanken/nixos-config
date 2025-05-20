{pkgs, ...}: {
  services.ollama = {
    enable = true;
    home = "/mnt/ollama";
    acceleration = "cuda";
  };
}
