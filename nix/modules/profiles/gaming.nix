# Used for a client device focused on gaming tasks
{flake, ...}: {
  imports = [
    flake.modules.profiles.shared-client
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    protontricks.enable = true;
  };
}
