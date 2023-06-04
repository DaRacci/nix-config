{ pkgs, config, ...  }: {
	home.packages = with pkgs; [ git-credential-1password ];

	programs = {
    git = {
      enable = true;
      package = pkgs.gitAndTools.gitFull;
      userEmail = "me@racci.dev";
      userName = "DaRacci";
      lfs.enable = true;

      signing = {
        signByDefault = false;
        # TODO dynamic
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVVzqHYt34dMsaFkX3K8m2vtam/RcUHiS00CBtLpolh";
      };

      aliases = {
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        resign = "!re() { git rebase --exec 'git commit --amend --no-edit -n -S' $1; }; re";
        caa = "commit -a --amend -C HEAD";
        bclean = "!f() { git branch --merged \${1-master} | grep -v ' \${1-master}$' | xargs -r git branch -d; }; f";
        retag = "!ret() { git checkout -q '\${1}' && GIT_COMMITER_DATE=$(git show --format=%aD | head -1) && git tag -a '\${2}' -m '\${3}' -s -f && git checkout -q master; }; ret";
      };

      ignores = [ ".idea" ];

      delta = {
        enable = true;
        options = {
          features = "decorations";
          whitespace-error-style = "22 reverse";

          decorations = {
            commit-decoration-style = "bond yellow box ul";
            file-decoration-style = "none";
            file-style = "bold yellow ul";
            syntax-theme = "TwoDark";
          };
        };
      };

      extraConfig = {
        init.defaultBranch = "master";
      
        credential.helper = "!git-credential-1password";
        gpg = {
          format = "ssh";
          ssh.program = "${pkgs._1password-gui}/bin/op-ssh-sign";
        };
      };
  	};
  
    gh = {
      enable = true;
      extensions = with pkgs; [ gh-markdown-preview ];
      enableGitCredentialHelper = false;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };

    gitui = {
      enable = true;
    };
  };

  # home.persistence = {
  #   "/persist/home/racci".directories = [ ".config/gh" ];
  # };
}
