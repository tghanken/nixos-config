{config, ...}: {
  imports = [
    ./system.nix
    ./headless.nix
    ./tailscale.nix
    ./secrets
  ];

  # GitHub PAT for Nix rate limits
  config.age.secrets.github_pat.rekeyFile = ./secrets/secret_files/github_pat.age;

  config.system.activationScripts.nix-access-tokens = {
    text = ''
      if [ -f "${config.age.secrets.github_pat.path}" ]; then
        mkdir -p /run/nix
        token=$(cat "${config.age.secrets.github_pat.path}")
        if [[ "$token" =~ ^access-tokens ]]; then
          echo "$token" > /run/nix/access-tokens.conf
        else
          echo "access-tokens = github.com=$token" > /run/nix/access-tokens.conf
        fi
        chmod 0400 /run/nix/access-tokens.conf
      fi
    '';
    deps = ["agenix"];
  };

  config.nix.extraOptions = ''
    !include /run/nix/access-tokens.conf
  '';
}
