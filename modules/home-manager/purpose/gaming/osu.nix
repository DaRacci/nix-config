# TODO :: Ensure audio components are installed;
{ config, pkgs, lib, ... }: with lib; let cfg = config.purpose.gaming.osu; in {
  options.purpose.gaming.osu = {
    enable = mkEnableOption "OSU!";

    lazerPackages = mkOption {
      type = types.package;
      default = pkgs.osu-lazer-bin;
      description = "The package to install for OSU! Lazer";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.lazerPackages ];

    user.persistence.directories = [
      {
        directory = ".local/share/osu";
        method = "symlink";
      }
    ];
  };
}
