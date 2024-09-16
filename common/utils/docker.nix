{
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
    storageDriver = "zfs";
    autoPrune = {
      enable = true;
      flags = ["--all"];
    };
  };
}
