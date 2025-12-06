{...}: {
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = false;
      setSocketVariable = true;
    };
    storageDriver = "zfs";
    autoPrune = {
      enable = true;
      flags = [];
    };
  };
}
