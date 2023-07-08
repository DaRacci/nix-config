{ config, pkgs, persistencePath, ... }: {
  home.packages = with pkgs; [ azure-cli ];

  home.sessionVariables.AZURE_CONFIG_DIR = "${config.xdg.configHome}/.azure";
  home.persistence."${persistencePath}".directories = [
    ".azure"
  ];
}
