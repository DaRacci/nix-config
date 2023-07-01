{ lib, config, pkgs, ... }: {
  programs.nushell = {
    enable = true;

    environmentVariables = {
      NODE_SKIP_PLATFORM_CHECK = "1"; # FUCK YOU COPILOT!
    };

    extraEnv = ''
    def-env load-sh-env [path: path] {
      let columns = (open $path
        | lines
        | filter {|line| (not ($line | is-empty)) and ($line | str starts-with "export ") } # Only keep actual variables
        | each {|line| $line | str substring 7..}                                           # Remove 'export '
        | split column '=' name value)                                                      # Split into columns

      for element in $columns {
        let value = ($element.value | str trim -c '"')
        let-env $element.name = $value
      } 
    }
    '';

    extraConfig = ''
    '';
  };

  programs.zoxide = lib.mkIf config.programs.zoxide.enable {
    enableNushellIntegration = true;
  };

  home.persistence."/persist/home/racci" = {
    files = [
      ".config/nushell/history.txt"
    ];
  };
}