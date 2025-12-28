{flake, ...}: let
  email = "tghanken@gmail.com";
  name = "Taylor Hanken";
in {
  imports = [
    flake.homeModules.headless
  ];

  home.username = "tghanken";
  home.homeDirectory = "/home/tghanken";

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
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
      aliases = {
        l = ["log" "-r" "(trunk()..@):: | (trunk()..@)-- | trunk()"];
        lwb = ["log" "-r" "ancestors(roots(trunk()..tracked_remote_bookmarks()),2) | ancestors(tracked_remote_bookmarks(),2) | trunk()"];
        lub = ["log" "-r" "ancestors(roots(trunk()..untracked_remote_bookmarks()),2) | ancestors(untracked_remote_bookmarks(),2) | trunk()"];
      };
      ui = {
        paginate = "never";
      };
    };
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
