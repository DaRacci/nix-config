{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs) prismlauncher;
  cfg = config.purpose.gaming.minecraft;
in
{
  options.purpose.gaming.minecraft = {
    enable = lib.mkEnableOption "Enable Minecraft support";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      prismlauncher
    ];

    user.persistence.directories = [
      ".local/share/PrismLauncher"
    ];
  };
}
