{ osConfig, config, pkgs, lib, ... }: {
  programs.nushell = lib.mkIf (osConfig.users.users.${config.home.username}.shell.pname == "nushell") {
    enable = true;

    environmentVariables = {
      NODE_SKIP_PLATFORM_CHECK = "1"; # FUCK YOU COPILOT!
    };

    extraEnv = ''
      def --env load-sh-env [path: path] {
        let columns = (open $path
          | lines
          | filter {|line| (not ($line | is-empty)) and ($line | str starts-with "export ") }
          | each {|line| $line | str substring 7..}
          | split column '=' name value
          | upsert value {|e| $e.value | str trim -c '"' }
          | upsert value {|e| replace_env_vars $e.value })

        for element in $columns {
          load-env { $"($element.name)": $element.value }
          # $env.$element.name $element.value
        }
      }

      def generic_type [variable: any] {
        mut type = ($variable | describe)
        let open_index = ($type | str index-of '<')

        if $open_index != -1 {
          $type = ($type | str substring ..$open_index)
        }

        $type
      }

      def replace_env_vars [string: string] {
        mut string = $string
        let regex = '\$(?:\{?(?P<key>[A-z_]+)(?::(?P<op>\+|-)(?P<else>[^}]*))?}?)'
        let matches = ($string | rg -o $regex -r "$0|$key|$op|$else" | lines | split column "|" original key op else)
        mut last_key = ""
        mut last_matched = false

        for $match in $matches {
          mut value = ""

          if ($last_key == $match.key and $match.op == '+') {
            if ($last_matched) {
              $value = $match.else
            }
          } else {
            $value = ($env | get -i $match.key)

            # Test for using default value
            if ($value == null and match.op == "-") {
              $value = $match.else
            } else {
              let type = (generic_type $value)

              $value = (match $type {
                closure | record => null
                list => ($value | str join ":")
                _ => ($value | into string)
              })
            }
          }

          $last_key = $match.key
          $last_matched = ($value != null)
          $string = ($string | str replace -n $match.original $value)
        }

        $string
      }

      load-sh-env ${config.home.homeDirectory}/.nix-profile/etc/profile.d/hm-session-vars.sh
    '';

    extraConfig = ''
      let carapace_completer = {|spans: list<string>|
        ${lib.getExe config.programs.carapace.package} $spans.0 nushell $spans
          | from json
          | if ($in | default [] | where value == $"($spans | last)ERR" | is-empty) { $in } else { null }
      }

      let fish_completer = {|spans|
        ${lib.getExe config.programs.fish.package} --command $'complete "--do-complete=($spans | str join " ")"'
          | $"value(char tab)description(char newline)" + $in
          | from tsv --flexible --no-infer
      }

      let zoxide_completer = {|spans|
        $spans | skip 1 | zoxide query -l ...$in | lines | where {|x| $x != $env.PWD}
      }

      let external_completer = {|spans|
        # Workaround for https://github.com/nushell/nushell/issues/8483
        let expanded_alias = scope aliases
          | where name == $spans.0
          | get -i 0.expansion

        let spans = if $expanded_alias != null {
          $spans
            | skip 1
            | prepend ($expanded_alias | split row " " | take 1)
        } else {
          $spans
        }

        match $spans.0 {
          git | nix | nix-shell | nix-store | nix-* => $fish_completer
          __zoxide_z | __zoxide_zi => $zoxide_completer
          _ => $carapace_completer
        } | do $in $spans
      }

      $env.config = {
        show_banner: false

        completions: {
          case_sensitive: false
          quick: true
          partial: true
          algorithm: "fuzzy"
          external: {
            enable: true
            completer: $external_completer
          }
        }
      }
    '';

    shellAliases = {
      neofetch = "${pkgs.hyfetch}/bin/neowofetch";
      nuut = "sudo nu -i --env-config $nu.env-path --config $nu.config-path";
    };
  };

  programs.zoxide = lib.mkIf config.programs.zoxide.enable {
    enableNushellIntegration = true;
  };

  user.persistence.files = [
    ".config/nushell/history.txt"
  ];
}
