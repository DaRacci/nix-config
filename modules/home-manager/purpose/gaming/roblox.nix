{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.purpose.gaming.roblox;
in
{
  options.purpose.gaming.roblox = {
    enable = mkEnableOption "Enable Roblox launcher";

    vinegarPackage = mkOption {
      type = types.package;
      default = pkgs.vinegar;
      description = "The package to use for Vinegar";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.vinegarPackage ];

    user.persistence.directories = [ ".local/share/vinegar/" ];

    home.file.".config/vinegar/config.toml".text = ''
      # See how to configure Vinegar on the documentation website:
      # https://vinegarhq.org/Configuration

      # sanitize_env=true
      # renderer=vulkan
      # discord_rpc=true
    '';
  };
}
