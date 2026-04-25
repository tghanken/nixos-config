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
      revset-aliases = {
        "closest_merge(to)" = "heads(::to & merges())";
      };
      aliases = {
        l = ["log" "-r" "(trunk()..@):: | (trunk()..@)-- | trunk()"];
        lwb = ["log" "-r" "ancestors(roots(trunk()..tracked_remote_bookmarks()),2) | ancestors(tracked_remote_bookmarks(),2) | trunk()"];
        lub = ["log" "-r" "ancestors(roots(trunk()..untracked_remote_bookmarks()),2) | ancestors(untracked_remote_bookmarks(),2) | trunk()"];
        # `jj stack <revset>` to include specific revs
        stack = ["rebase" "--after" "trunk()" "--before" "megamerge" "--revisions"];
        # `jj stage` to include the whole stack after the megamerge
        stage = ["stack" "megamerge+:: ~ empty()"];
        # `jj restack` to rebase your changes onto `trunk()`
        restack = ["rebase" "--destination" "trunk()" "--source" "roots(trunk()..) & mutable()"];
        # clean empty commits after they are squashed and merged.
        clean = ["abandon" "empty() & mutable() ~ merges() ~ bookmarks()"];
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
