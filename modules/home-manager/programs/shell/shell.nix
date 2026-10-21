{
  inputs,
  osConfig ? null,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkMerge mkEnableOption;
  cfg = config.programSets.shell;

  isPrimaryShell =
    pname: osConfig != null -> osConfig.users.users.${config.home.username}.shell.pname == pname;
in
{
  options.programSets.shell = {
    minimal = mkEnableOption "minimal installation" // {
      default = osConfig != null && osConfig.host.device.role == "server";
      defaultText = "enabled if not a server";
    };

    enableFish = mkEnableOption "fish shell" // {
      default = isPrimaryShell "fish";
      defaultText = "enabled if user shell is fish";
    };

    enableNushell = mkEnableOption "nushell" // {
      default = isPrimaryShell "nushell";
      defaultText = "enabled if user shell is nushell";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      programs.atuin.enable = true;
    })

    (mkIf cfg.enableFish {
      programs.fish = {
        enable = true;
        generateCompletions = !cfg.minimal;
        package = if cfg.minimal then pkgs.fishMinimal else pkgs.fish;
      };

      user.persistence.files = [ ".local/share/fish/fish_history" ];
    })

    (mkIf cfg.enableNushell {
      home.packages = [
        inputs.bash-env-nushell.packages.${pkgs.stdenv.hostPlatform.system}.default
        inputs.bash-env-json.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];

      programs.zoxide.enable = true;
      programs.nushell = {
        enable = true;

        # FUCK YOU COPILOT!
        environmentVariables.NODE_SKIP_PLATFORM_CHECK = 1;

        shellAliases = {
          nuut = "sudo nu -i --env-config $nu.env-path --config $nu.config-path";
        };

        extraEnv = ''
          use "${inputs.bash-env-nushell}/bash-env.nu"
          bash-env "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh" | load-env
        '';

        extraConfig = ''
          let carapace_completer = {|spans|
            load-env {
             	CARAPACE_SHELL_BUILTINS: (help commands | where category != "" | get name | each { split row " " | first } | uniq  | str join "\n")
             	CARAPACE_SHELL_FUNCTIONS: (help commands | where category == "" | get name | each { split row " " | first } | uniq  | str join "\n")
            }

            ${lib.getExe config.programs.carapace.package} $spans.0 nushell ...$spans
              | from json
          }

          let fish_completer = {|spans|
            ${lib.getExe config.programs.fish.package} --command $'complete "--do-complete=($spans | str join " ")"'
              | $"value(char tab)description(char newline)" + $in
              | from tsv --flexible --no-infer
          }

          let zoxide_completer = {|spans|
            $spans | skip 1 | ${lib.getExe config.programs.zoxide.package} query -l ...$in | lines | where {|x| $x != $env.PWD}
          }

          let external_completer = {|spans|
            # if the current command is an alias, get it's expansion
            let expanded_alias = (scope aliases | where name == $spans.0 | $in.0?.expansion?)

            # overwrite
            let spans = (if $expanded_alias != null  {
              # put the first word of the expanded alias first in the span
              $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
            } else {
              $spans | skip 1 | prepend ($spans.0)
            })

            match $spans.0 {
              # git | nix | nix-shell | nix-store | nix-* => $fish_completer
              __zoxide_z | __zoxide_zi => $zoxide_completer
              _ => $carapace_completer
            } | do $in $spans
          }

          $env.config.completions.external.completer = $external_completer
        '';

        settings = {
          show_banner = false;
          completions = {
            case_sensitive = false;
            quick = true;
            partial = true;
            algorithm = "prefix";
            use_ls_colors = true;
            external = {
              enable = true;
              max_results = 100;
            };
          };
        };
      };

      user.persistence = {
        directories = [ ".local/share/zoxide" ];
        files = [ ".config/nushell/history.txt" ];
      };
    })
  ];
}
