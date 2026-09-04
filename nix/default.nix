{...}: {
  imports = [
    ./apps
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
      server = ./roles/server.nix;
    };
    services = {
      github-runner = ./services/github-runner.nix;
    };
    features = {
      ai = ./features/ai.nix;
      development = ./features/development.nix;
      gaming = ./features/gaming.nix;
    };
    users = {
      tghanken = ./users/tghanken.nix;
    };
  };
}
