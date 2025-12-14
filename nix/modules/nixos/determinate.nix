{inputs, ...}: {
  imports = [
    inputs.determinate.nixosModules.default
  ];
  environment.etc = {
    "nix/nix.custom.conf" = {
      text = "eval-cores = 0";
    };
  };
}
