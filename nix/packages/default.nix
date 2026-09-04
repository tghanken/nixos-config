{
  self,
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    config,
    ...
  }: {
    packages = {
      flake-check = import ../lib/flake-check-tier.nix {
        inherit pkgs;
        flakeSrc = pkgs.lib.cleanSource self;
        name = "flake-check";
      };
      node-bootstrap-iso = import ./node-bootstrap-iso.nix {
        inherit inputs self;
      };
      formatter = config.treefmt.build.wrapper;
    };
  };
}
