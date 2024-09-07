nom build .#nixosConfigurations.nixos-usb.config.system.build.isoImage;

sudo dd if=./result/iso/*.iso of=/dev/sdX status=progress;

sync;