{inputs, ...}: {
  perSystem = {
    pkgs,
    inputs',
    config,
    ...
  }: let
    reimageHostPkg = import ./reimage-host.nix {
      inherit pkgs;
      lib = inputs.nixpkgs.lib;
      nixos-anywhere = inputs'.nixos-anywhere.packages.default;
      agenix-rekey-pkg = config.agenix-rekey.package;
    };

    ingestHostKeysPkg = import ./ingest-host-keys.nix {
      inherit pkgs;
      lib = inputs.nixpkgs.lib;
    };

    updateDiskLayoutsPkg = import ./update-disk-layouts.nix {
      inherit pkgs;
      inherit (config) self;
    };
  in {
    packages = {
      reimage-host = reimageHostPkg;
      ingest-host-keys = ingestHostKeysPkg;
      update-disk-layouts = updateDiskLayoutsPkg;
    };

    apps = {
      reimage-host = {
        type = "app";
        program = "${reimageHostPkg}/bin/reimage-host";
      };
      ingest-host-keys = {
        type = "app";
        program = "${ingestHostKeysPkg}/bin/ingest-host-keys";
      };
      update-disk-layouts = {
        type = "app";
        program = "${updateDiskLayoutsPkg}/bin/update-disk-layouts";
      };
    };
  };
}
