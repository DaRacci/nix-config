{ lib, config, pkgs, persistenceDirectory, ... }: {
  programs.nushell = {
    enable = true;

    environmentVariables = {
      NODE_SKIP_PLATFORM_CHECK = "1"; # FUCK YOU COPILOT!
    };

    extraEnv = ''
      def-env load-sh-env [path: path] {
        let columns = (open $path
          | lines
          | filter {|line| (not ($line | is-empty)) and ($line | str starts-with "export ") }
          | each {|line| $line | str substring 7..}
          | split column '=' name value
          | upsert value {|e| $e.value | str trim -c '"' }
          | upsert value {|e| replace_env_vars $e.value })

        for element in $columns {
          let-env $element.name = $element.value
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
          $string = ($string | str replace -ns $match.original $value)
        }

        $string
      }

      load-sh-env ~/.nix-profile/etc/profile.d/hm-session-vars.sh
    '';

    extraConfig = ''
      let-env config = {
        show_banner: false

        rm: {
          always_trash: true
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

  home.persistence."${persistenceDirectory}" = {
    files = [
      ".config/nushell/history.txt"
    ];
  };

  home.file.".config/nushell/login.nu".text = ''
     
  '';
}


