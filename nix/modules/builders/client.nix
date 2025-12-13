{
  config,
  lib,
  ...
}: let
  defaultBuildConfig = {
    sshUser = "nixbuilder";
    systems = ["x86_64-linux" "aarch64-linux"];
    protocol = "ssh-ng";
    maxJobs = 8;
    speedFactor = 0;
    supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    mandatoryFeatures = [];
  };
  hosts = [
    # Servers First
    # {
    #   hostName = "syno-vm";
    #   speedFactor = 2;
    #   maxJobs = 4;
    # }
    # {
    #   hostName = "nixos-rpi4-1";
    #   maxJobs = 2;
    # }
    # {
    #   hostName = "nixos-rpi4-2";
    #   maxJobs = 2;
    # }
    # {
    #   hostName = "nixos-rpi4-3";
    #   maxJobs = 2;
    # }

    # Then Desktops
    {
      hostName = "inwin-tower";
      speedFactor = 8;
      maxJobs = 8;
    }
    {
      hostName = "nixos-thinkpad";
      speedFactor = 8;
      maxJobs = 12;
    }
  ];
  filtered_hosts = builtins.filter (host: config.networking.hostName != host.hostName) hosts;
  build_hosts = builtins.map (host: defaultBuildConfig // host) filtered_hosts;
  substituters = builtins.map (host: "http://${host.hostName}.myth-chameleon.ts.net:16893") build_hosts;
  sshHostsConfig =
    builtins.map (host: ''
      Host ${host.hostName}
        StrictHostKeyChecking no
        UpdateHostkeys yes
        ConnectTimeout=1
        ConnectionAttempts=1
    '')
    build_hosts;
  sshConfigString = lib.concatStringsSep "\n" sshHostsConfig;
in {
  imports = [
    ./user.nix
  ];
  nix.buildMachines = build_hosts;
  nix.settings.substituters = substituters;
  programs.ssh.extraConfig = sshConfigString;

  nix.distributedBuilds = true;
  nix.settings = {
    builders-use-substitutes = true;
    trusted-public-keys = [home-builders:U3PWObVWROdM+8rlJqk70qE9aeffp9RsKmoCojx7XQ0=];
  };
}
