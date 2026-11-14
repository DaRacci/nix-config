{
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
      programs.zoxide.enable = true;
      user.files.persistence.directories = [ ".local/share/zoxide" ];
    })

    (mkIf cfg.enableFish {
      programs.fish = {
        enable = true;
        generateCompletions = !cfg.minimal;
        package = if cfg.minimal then pkgs.fishMinimal else pkgs.fish;
      };

      user.files.persistence.files = [ ".local/share/fish/fish_history" ];
    })

    (mkIf cfg.enableNushell {
      programs.nushell = {
        enable = true;
        loadSessionVariables = true;

        # FUCK YOU COPILOT!
        environmentVariables.NODE_SKIP_PLATFORM_CHECK = 1;

        shellAliases = {
          nuut = "sudo nu -i --env-config $nu.env-path --config $nu.config-path";
        };

        extraConfig = ''
          let carapace_completer = {|place: record|
            load-env {
             	CARAPACE_SHELL_BUILTINS: (help commands | where category != "" | get name | each { split row " " | first } | uniq  | str join "\n")
             	CARAPACE_SHELL_FUNCTIONS: (help commands | where category == "" | get name | each { split row " " | first } | uniq  | str join "\n")
            }

            ${lib.getExe config.programs.carapace.package} $place.command.0 nushell ...$place.command
              | from json
          }

          let fish_completer = {|place: record|
            ${lib.getExe config.programs.fish.package} --command $'complete "--do-complete=($place.command | str join " ")"'
              | $"value(char tab)description(char newline)" + $in
              | from tsv --flexible --no-infer
          }

          let zoxide_completer = {|place: record|
            $place.command | skip 1 | ${lib.getExe config.programs.zoxide.package} query -l ...$in | lines | where {|x| $x != $env.PWD}
          }

          let external_completer = {|place: record|
            # if the current command is an alias, get it's expansion
            let expanded_alias = (scope aliases | where name == $place.command.0 | $in.0?.expansion?)

            # overwrite
            let place = (if $expanded_alias != null  {
              # put the first word of the expanded alias first in the span
              $place | update command ($place.command | skip 1 | prepend ($expanded_alias | split row " " | take 1))
            } else {
              $place | update command ($place.command | skip 1 | prepend ($place.command.0))
            })

            match $place.command.0 {
              # git | nix | nix-shell | nix-store | nix-* => $fish_completer
              __zoxide_z | __zoxide_zi => $zoxide_completer
              _ => $carapace_completer
            } | do $in $place
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

      user.files.persistence.files = [ ".config/nushell/history.txt" ];
    })
  ];
}
