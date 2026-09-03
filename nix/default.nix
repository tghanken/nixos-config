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
      restic-rest-server = ./services/restic-rest-server.nix;
    };
    features = {
      ai = ./features/ai.nix;
      backup = ./features/backup.nix;
      development = ./features/development.nix;
      gaming = ./features/gaming.nix;
    };
    users = {
      tghanken = ./users/tghanken.nix;
    };
  };
}
