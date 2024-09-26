{
  config,
  lib,
  pkgs,
  ...
}: {
  nix.buildMachines = [
    {
      hostName = "nixos-thinkpad";
      sshUser = "nixbuilder";
      system = "x86_64-linux";
      protocol = "ssh";
      maxJobs = 8;
      speedFactor = 0;
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      mandatoryFeatures = [];
    }
    {
      hostName = "inwin-tower";
      sshUser = "nixbuilder";
      system = "x86_64-linux";
      protocol = "ssh";
      maxJobs = 8;
      speedFactor = 0;
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      mandatoryFeatures = [];
    }
  ];
  nix.settings.substituters = [
    (if (config.networking.hostName != "nixos-thinkpad") then "http://nixos-thinkpad.myth-chameleon.ts.net:16893" else "")
    (if (config.networking.hostName != "inwin-tower") then "http://inwin-tower.myth-chameleon.ts.net:16893" else "")
  ];
  programs.ssh.extraConfig = ''
      Host nixos-thinkpad
        StrictHostKeyChecking no
        ConnectTimeout=1
        ConnectionAttempts=1

      Host inwin-tower
          StrictHostKeyChecking no
          ConnectTimeout=1
          ConnectionAttempts=1
  '';

  users.users.nixbuilder = {
    isNormalUser = true;
    description = "Nix builder";
    group = "nixbuilder";
  };
  users.groups.nixbuilder = {};
  nix.settings.trusted-users = ["nixbuilder"];

  # TODO: Need to add a signing key to the trusted-users list
  services.nix-serve = {
    enable = true;
    port = 16893;
    openFirewall = true;
  };

  nix.distributedBuilds = true;
  nix.settings = {
    builders-use-substitutes = true;
  };
}
