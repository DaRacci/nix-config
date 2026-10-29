{
  inputs,
  osConfig ? null,
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf (osConfig == null || osConfig.users.users.${config.home.username}.shell.pname == "nushell")
  {
    home.packages = [
      inputs.bash-env-nushell.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.bash-env-json.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    programs.nushell = {
      enable = true;

      environmentVariables = {
        NODE_SKIP_PLATFORM_CHECK = "1"; # FUCK YOU COPILOT!
      };

      extraEnv = ''
        use "${inputs.bash-env-nushell}/bash-env.nu"
        bash-env ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh | load-env
      '';

      extraConfig = ''
        let carapace_completer = {|place: record|
          ${lib.getExe config.programs.carapace.package} $place.command.0 nushell ...$place.command
            | from json
            | if ($in | default [] | where value == $"($place.command | last)ERR" | is-empty) { $in } else { null }
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
          match $place.command.0 {
            # git | nix | nix-shell | nix-store | nix-* => $fish_completer
            __zoxide_z | __zoxide_zi => $zoxide_completer
            _ => $carapace_completer
          } | do $in $place
        }

        $env.config = {
          show_banner: false

          completions: {
            case_sensitive: false
            quick: true
            partial: true
            algorithm: "prefix"
            use_ls_colors: true
            external: {
              enable: true
              max_results: 100
              completer: $external_completer
            }
          }
        }
      '';

      shellAliases = {
        nuut = "sudo nu -i --env-config $nu.env-path --config $nu.config-path";
      };
    };

    programs.zoxide = lib.mkIf config.programs.zoxide.enable { enableNushellIntegration = true; };

    user.persistence.files = [ ".config/nushell/history.txt" ];
  }
