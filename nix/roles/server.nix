{
  lib,
  config,
  ...
}: {
  imports = [
    ../core
  ];

  options.roles.server.qemu = lib.mkEnableOption "QEMU guest support";

  config = lib.mkMerge [
    {
      storage.role = lib.mkDefault (
        if config.roles.server.qemu
        then "server-remote"
        else "server-local"
      );
      storage.disks = lib.mkIf config.roles.server.qemu (lib.mkDefault ["/dev/vda"]);
    }
    (lib.mkIf config.roles.server.qemu {
      boot.initrd.availableKernelModules = [
        "virtio_net"
        "virtio_pci"
        "virtio_mmio"
        "virtio_blk"
        "virtio_scsi"
        "9p"
        "9pnet_virtio"
        "virtiofs"
      ];
      boot.initrd.kernelModules = [
        "virtio_balloon"
        "virtio_console"
        "virtio_rng"
        "virtio_gpu"
      ];
    })
  ];
}
