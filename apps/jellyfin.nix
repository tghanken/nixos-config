{pkgs, ...}: {
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
  };
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver # previously vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      # vpl-gpu-rt # QSV on 11th gen or newer
      intel-media-sdk # QSV up to 11th gen
    ];
  };

  fileSystems."/mnt/jellyfin-media" = {
    # NFS set to wildcard hostname, readonly, map all users to admin.
    device = "pinonnas.myth-chameleon.ts.net:/volume1/media-final";
    fsType = "nfs";
    options = [
      "nfsvers=4.1"
      "ro"
      "x-systemd.automount"
      "noauto"
    ];
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];
}
