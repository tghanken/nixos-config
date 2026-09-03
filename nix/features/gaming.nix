_: {
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    protontricks.enable = true;
  };

  disko.devices.zpool.zroot.datasets."local/steam" = {
    type = "zfs_fs";
    mountpoint = "/home/tghanken/.local/share/Steam";
    options."com.sun:auto-snapshot" = "false";
  };
}
