# Custom packages
{
  pkgs,
  inputs,
  system,
  ...
}: let
  inherit (pkgs) callPackage;

  # Bootstrap modules for image generation
  bootstrapModules = [
    ../hosts/utils/nixos-bootstrap/default.nix
  ];
in {
  windsurf = callPackage ./windsurf.nix {inherit inputs;};

  # Bootstrap images using nixos-generators
  nixos-vm-bootstrap-image = inputs.nixos-generators.nixosGenerate {
    inherit system;
    modules = bootstrapModules;
    format = "iso";
  };

  # To burn image: sudo zstd -cd ./result/sd-image/{img}.img.zst | sudo dd bs=1M of=/dev/sdX status=progress
  nixos-rpi-bootstrap-image = inputs.nixos-generators.nixosGenerate {
    system = "aarch64-linux";
    modules = bootstrapModules;
    format = "sd-aarch64";
  };
}
