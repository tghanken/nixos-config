nix build .#nixosConfigurations.nixos-usb.config.system.build.isoImage;

dd if=result/iso/*.iso of=/dev/sdX status=progress;

sync;