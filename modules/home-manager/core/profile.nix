{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.core.profile = {
    avatar = {
      path = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.face";
        description = "Path to user avatar image.";
      };
    };

    wallpaper = {
      directory = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/Pictures/Wallpapers";
        description = "Path to wallpaper image directory.";
      };
    };

    location = {
      secret = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SOPS secret name used for Noctalia location address.";
      };
    };
  };

  config = {
    # This doesn't work very well, needs a file manually moving to the persist dir first
    # Caelestia doesn't respect an existing symlink and will just overwrite it.
    user.persistence.files = [ ".face" ];
  };
}
