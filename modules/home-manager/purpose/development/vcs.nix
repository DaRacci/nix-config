{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    mkMerge
    mkOption
    mkEnableOption
    optionalAttrs
    literalExpression
    concatStringsSep
    ;
  inherit (types) str enum nullOr;
  cfg = config.purpose.development.vcs;

  jj-desc-wrapped = pkgs.writeShellScriptBin "jj-desc" ''
    export LLM_MODEL="deepseek/deepseek-v4.1-flash"
    export LLM_PROVIDER="openrouter"
    export OPENROUTER_API_KEY="$(cat ${config.sops.secrets.OPENROUTER_API_KEY.path})"
    exec ${pkgs.jj-desc}/bin/jj-desc "$@"
  '';
in
{
  options.purpose.development.vcs = {
    enable = mkEnableOption "vcs" // {
      default = config.purpose.development.enable;
      defaultText = literalExpression "config.purpose.development.enable";
    };

    primaryVCS = mkOption {
      description = "The primary version control system to use, this changes the program set that gets installed and configured.";
      type = enum [
        "git"
        "jujutsu"
      ];
      default = "jujutsu";
    };

    user = {
      email = mkOption {
        description = "The email to use for version control operations, this is your commit email.";
        type = nullOr str;
        default = null;
      };

      name = mkOption {
        description = "The name to use for version control operations, this is your commit display name.";
        type = str;
        default = lib.mine.strings.capitalise config.home.username;
        defaultText = "home-manager username with capitalisation for the first character";
      };

      publicKey = mkOption {
        description = "The SSH key to use for signing commits.";
        type = nullOr str;
        default =
          if builtins.pathExists config.core.profile.identity.publicKey then
            builtins.readFile config.core.profile.identity.publicKey
          else
            null;
        defaultText = literalExpression ''builtins.readFile "''${config.core.profile.identity.publicKey}"'';
      };
    };

    enableJJDescWrapper = mkEnableOption "jj-desc wrapper" // {
      default = false;
      longDescription = ''
        Adds a small wrapper around `jj-desc` that sets the `LLM_MODEL`, `LLM_PROVIDER` and `OPENROUTER_API_KEY` environment variables for you.
        This expects that you have the `OPENROUTER_API_KEY` secret available in your sops secrets, and will fail to build if it is not available.
      '';
    };
  };

  config = mkMerge [
    {
      assertions = [
        {
          assertion = cfg.enable -> config.purpose.development.enable;
          message = "The development purpose must be enabled to use `purpose.development.vcs` options.";
        }
      ];
    }

    (mkIf cfg.enable {
      home.packages = [
        pkgs.lumen
      ];

      programs = {
        # Codeberg SSH auth expects the user to be "git"
        ssh.settings."codeberg.org" = {
          User = "git";
        };

        git = {
          enable = true;
          package = pkgs.gitFull;
          lfs.enable = true;

          settings = {
            user = {
              inherit (cfg.user) name;
            }
            // optionalAttrs (cfg.user.email != null) {
              inherit (cfg.user) email;
            };

            init.defaultBranch = "master";
            pull.rebase = true;

            alias = {
              lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
              resign = "!re() { git rebase --exec 'git commit --amend --no-edit -n -S' $1; }; re";
              caa = "commit -a --amend -C HEAD";
              bclean = "!f() { git branch --merged \${1-master} | grep -v ' \${1-master}$' | xargs -r git branch -d; }; f";
              retag = "!ret() { git checkout -q '\${1}' && GIT_COMMITTER_DATE=$(git show --format=%aD | head -1) && git tag -a '\${2}' -m '\${3}' -s -f && git checkout -q master; }; ret";
            };
          };

          ignores = [
            ".idea"
            ".jj"
          ];
        };

        gh = {
          enable = true;
          extensions = [
            pkgs.gh-markdown-preview
            pkgs.gh-notify
          ];

          gitCredentialHelper.enable = true;
          settings = {
            git_protocol = "ssh";
            prompt = "enabled";
          };
        };

        gh-dash.enable = true;

        delta = {
          enable = true;
          enableGitIntegration = true;
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
      };
    })

    (mkIf (cfg.enable && cfg.user.publicKey != null) {
      programs.git = {
        signing = {
          format = "ssh";
          key = cfg.user.publicKey;
          signByDefault = true;
        };

        settings.gpg.ssh.allowedSignersFile =
          (pkgs.writeTextFile {
            name = "allowed-signers";
            text = concatStringsSep "\n" [
              "${config.programs.git.settings.user.email} ${cfg.user.publicKey}"
            ];
          }).outPath;
      };

      programs.jujutsu.settings = {
        ui.show-cryptographic-signatures = true;
        git.sign-on-push = true;
        signing = {
          behavior = "drop"; # Lazyily sign commits at push time only via `git.sign-on-push`
          backend = "ssh";
          key = cfg.user.publicKey;
        };
      };
    })

    (mkIf (cfg.enable && cfg.primaryVCS == "git") {
      programs.gitui.enable = true;
    })

    (mkIf (cfg.enable && cfg.primaryVCS == "jujutsu") {
      sops.secrets = mkIf cfg.enableJJDescWrapper {
        OPENROUTER_API_KEY = { };
      };

      home.packages = [
        pkgs.meld
        pkgs.watchman
        pkgs.jj-pre-push
      ]
      ++ (if cfg.enableJJDescWrapper then [ jj-desc-wrapped ] else [ pkgs.jj-desc ]);

      programs = {
        delta.enableJujutsuIntegration = true;

        jujutsu = {
          enable = true;
          settings = {
            user = {
              inherit (cfg.user) name;
            }
            // optionalAttrs (cfg.user.email != null) {
              inherit (cfg.user) email;
            };

            ui = {
              default-branch = "master";
              diff-editor = "meld-3";
              merge-editor = "meld";
            };

            git.private-commits = "description('wip:*') | description('private:*')";
            revsets.immutable = "description('wip:*') | description('private:*')";

            aliases = {
              push = [
                "util"
                "exec"
                "--"
                "bash"
                "-c"
                ''exec jj-pre-push --checker prek push "$@"''
                ""
              ];
            };

            fsmonitor = {
              backend = "watchman";
              watchman.register-snapshot-trigger = true;
            };
          };
        };

        jjui = {
          enable = true;
          settings = {
            actions = [
              {
                name = "jj-push";
                lua = ''
                  jj_async("push")
                  revisions.refresh()
                '';
              }
              {
                name = "jj-push-selected";
                lua = ''
                  jj_async("push", "-r", context.commit_id())
                  revisions.refresh()
                '';
              }
              {
                name = "jj-desc";
                lua = ''
                  revisions.refresh()
                  local selectedRevisions = revisions.checked()
                  if #selectedRevisions == 0 then
                    selectedRevisions = { revisions.current() }
                  end

                  local toProcess = { }
                  for _, rev in ipairs(selectedRevisions) do
                    local description = rev.description()
                    if description ~= nil and description ~= "" then
                      local overwrite = choose("Overwrite description for " .. rev.id() .. "?", { "Yes", "No" })
                      if overwrite == "Yes" then
                        table.insert(toProcess, rev.id())
                      end
                    else
                      table.insert(toProcess, rev.id())
                    end
                  end

                  if #toProcess == 0 then
                    return
                  end

                  local result = exec_shell("jj-desc", "-r", unpack(toProcess))
                  flash(result)

                  revisions.refresh()
                '';
              }
            ];
            bindings = [
              {
                action = "jj-push";
                seq = [
                  "x"
                  "p"
                ];
                scope = "revisions";
                desc = "jj push";
              }
              {
                action = "jj-push-selected";
                seq = [
                  "x"
                  "P"
                ];
                scope = "revisions";
                desc = "jj push selected bookmark(s)";
              }
              {
                action = "jj-desc";
                seq = [
                  "x"
                  "d"
                ];
                scope = "revisions";
                desc = "generate description for selected revision(s)";
              }
            ];
          };
        };
      };
    })
  ];
}
