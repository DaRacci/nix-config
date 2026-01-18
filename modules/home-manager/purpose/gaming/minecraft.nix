{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.gaming.minecraft;
in
{
  options.purpose.gaming.minecraft = {
    enable = lib.mkEnableOption "Enable Minecraft support";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      gdlauncher-carbon
      prism
    ];

    user.persistence.directories = [
      ".local/share/gdlauncher_carbon"
      ".local/share/PrismLauncher"
    ];
  };
}
