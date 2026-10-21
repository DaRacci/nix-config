{
  osConfig,
  pkgs,
  ...
}:
{
  programs.carapace = {
    enable = osConfig == null || osConfig.host.device.role != "server";
    package = pkgs.carapace;
    enableNushellIntegration = false; # We have our own implementation
  };
}
