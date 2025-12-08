{
  osConfig,
  config,
  pkgs,
  ...
}:
{
  programs.carapace = {
    enable = osConfig == null || osConfig.host.device.role != "server";
    package = pkgs.carapace;

    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;
    enableFishIntegration = config.programs.fish.enable;
    enableNushellIntegration = false; # We have our own implementation
  };
}
