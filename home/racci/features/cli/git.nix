{
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.meld
    pkgs.watchman
  ];

  programs = rec {
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

        gpg = {
          format = "ssh";
          ssh = {
            program = "${pkgs._1password-gui}/bin/op-ssh-sign";
            allowedSignersFile =
              let
                file = pkgs.writeTextFile {
                  name = "allowed-signers";
                  text = pkgs.lib.concatStringsSep "\n" [
                    "me@racci.dev ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVVzqHYt34dMsaFkX3K8m2vtam/RcUHiS00CBtLpolh"
                  ];
                };
              in
              file.outPath;
          };
        };
      };

      ignores = [ ".idea" ];

      signing = {
        signByDefault = true;
        # TODO dynamic
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVVzqHYt34dMsaFkX3K8m2vtam/RcUHiS00CBtLpolh";
      };
    };

    jujutsu = {
      enable = true;
      settings = {
        inherit (git.settings) user;

        ui = {
          show-cryptographic-signatures = true;
          diff-editor = "meld-3";
          merge-editor = "meld";
        };

        signing = {
          behavior = "own";
          backend = "ssh";
          key = git.signing.key;
        };

        git = {
          private-commits = "description('wip:*') | description('private:*')";
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
        gh-copilot
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
