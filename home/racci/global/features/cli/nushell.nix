{ lib, config, ... }: {
  programs.nushell = {
    enable = true;

    environmentVariables = {
      NODE_SKIP_PLATFORM_CHECK = "1"; # FUCK YOU COPILOT!
    };
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