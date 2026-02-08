{
  config,
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.meld
    pkgs.watchman
  ];

  programs = {
    git = {
      enable = true;
      package = pkgs.gitFull;
      lfs.enable = true;

      settings = {
        user.email = "me@racci.dev";
        user.name = "DaRacci";

        aliases = {
          lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
          resign = "!re() { git rebase --exec 'git commit --amend --no-edit -n -S' $1; }; re";
          caa = "commit -a --amend -C HEAD";
          bclean = "!f() { git branch --merged \${1-master} | grep -v ' \${1-master}$' | xargs -r git branch -d; }; f";
          retag = "!ret() { git checkout -q '\${1}' && GIT_COMMITTER_DATE=$(git show --format=%aD | head -1) && git tag -a '\${2}' -m '\${3}' -s -f && git checkout -q master; }; ret";
        };

        init.defaultBranch = "master";
        pull.rebase = true;
        signing.signByDefault = true;

        gpg = {
          format = "ssh";
          ssh.program = "${pkgs._1password-gui}/bin/op-ssh-sign";
        };
      };

      ignores = [
        ".idea"
        ".jj"
      ];
    };

    jujutsu = {
      enable = true;
      settings = {
        inherit (config.programs.git.settings) user;

        ui = {
          default-branch = "master";
          show-cryptographic-signatures = true;
          diff-editor = "meld-3";
          merge-editor = "meld";
        };

        signing = {
          behavior = "drop"; # Lazyily sign commits at push time only
          backend = "ssh";
          key = config.programs.git.settings.signing.key;
        };

        git = {
          private-commits = "description('wip:*') | description('private:*')";
          sign-on-push = true;
        };

        revsets = {
          immutable = "description('wip:*') | description('private:*')";
        };

        fsmonitor = {
          backend = "watchman";
          watchman.register-snapshot-trigger = true;
        };
      };
    };

    jjui.enable = true;

    delta = {
      enable = true;
      enableGitIntegration = true;
      enableJujutsuIntegration = true;
      options = {
        features = "decorations";
        whitespace-error-style = "22 reverse";

        decorations = {
          commit-decoration-style = "bold yellow box ul";
          file-decoration-style = "none";
          file-style = "bold yellow ul";
          syntax-theme = "TwoDark";
        };
      };
    };

    gh = {
      enable = true;
      extensions = with pkgs; [
        gh-markdown-preview
        gh-notify
        gh-eco
      ];
      gitCredentialHelper.enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };

    gh-dash = {
      enable = true;
      settings = {
        repoPaths = {
          "DaRacci/nix-config" = "/persist/nix-config";
          "DaRacci/*" = "~/Projects/Coding/*";
          "AMTSupport/*" = "~/Projects/Coding/AMT/*";
          "NixOS/*" = "~/Projects/Coding/nix/*";
        };
      };
    };

    gitui = {
      enable = true;
    };
  };
}
