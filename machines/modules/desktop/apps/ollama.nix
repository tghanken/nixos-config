{pkgs, ...}: {
  users.users.ollama = {
    isNormalUser = false;
    description = "Ollama";
  };
  services.ollama = {
    enable = true;
    home = "/mnt/ollama";
    acceleration = "cuda";
    user = "ollama";
  };
}
