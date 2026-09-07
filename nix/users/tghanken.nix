{
  lib,
  config,
  ...
}: let
  email = "tghanken@gmail.com";
  name = "Taylor Hanken";
in {
  # NixOS User
  users.users.tghanken = {
    isNormalUser = true;
    description = "Taylor Hanken";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    hashedPassword = "$6$aVX13r8lw5yvxWJZ$TrXrqKub2dJArKGyZ75l5AQC.yIh8ysgigZniYT.ZkvQRvjgb45oFNUnFIUd5xTfE0JXzFzPHwMWdJcdth9Tj1";
    openssh.authorizedKeys.keys =
      (import ../lib/keys.nix {inherit lib;}).readUserKeys "tghanken";
  };

  nix.settings.trusted-users = ["tghanken"];

  # Home Manager User
  home-manager.users.tghanken = {
    home.username = "tghanken";
    home.homeDirectory = "/home/tghanken";

    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        beads.role = "maintainer";
        user = {
          inherit name email;
        };
      };
    };

    programs.jujutsu = {
      enable = true;
      settings = {
        user = {
          inherit name email;
        };
        revset-aliases = {
          "closest_merge(to)" = "heads(::to & merges())";
        };
        aliases = {
          l = ["log" "-r" "(trunk()..@):: | (trunk()..@)-- | trunk()"];
          lwb = ["log" "-r" "ancestors(roots(trunk()..tracked_remote_bookmarks()),2) | ancestors(tracked_remote_bookmarks(),2) | trunk()"];
          lub = ["log" "-r" "ancestors(roots(trunk()..untracked_remote_bookmarks()),2) | ancestors(untracked_remote_bookmarks(),2) | trunk()"];
          stack = ["rebase" "--after" "trunk()" "--before" "megamerge" "--revisions"];
          stage = ["stack" "megamerge+:: ~ empty()"];
          restack = ["rebase" "--destination" "trunk()" "--source" "roots(trunk()..) & mutable()"];
          clean = ["abandon" "empty() & mutable() ~ merges() ~ bookmarks()"];
        };
        ui = {
          paginate = "never";
        };
      };
    };

    home.stateVersion = "25.11";
    programs.home-manager.enable = true;
  };

  environment.persistence."/persist/user".users.tghanken = lib.mkIf (config.storage.role == "workstation") {
    directories = [
      "Documents"
      "Downloads"
      "Pictures"
      "Repos"
      ".ssh"
      ".gnupg"
    ];
    files = [
      ".zsh_history"
      ".bash_history"
    ];
  };
}
