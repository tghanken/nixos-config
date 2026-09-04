{...}: {
  imports = [
    ./hosts
    ./devshells
    ./formatter
    ./packages
    ./checks
  ];

  flake.modules = {
    core = ./core;
    roles = {
      workstation = ./roles/workstation.nix;
      server = {
        default = ./roles/server/default.nix;
        local = ./roles/server/local.nix;
        remote = ./roles/server/remote.nix;
      };
    };
    features = {
      ai = ./features/ai.nix;
      development = ./features/development.nix;
      gaming = ./features/gaming.nix;
      github-runner = ./features/github-runner.nix;
      netbird = ./features/netbird.nix;
      secrets = ./features/secrets;
    };
    users = {
      tghanken = ./users/tghanken.nix;
    };
  };
}
