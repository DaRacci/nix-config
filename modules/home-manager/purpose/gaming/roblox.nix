{ config, lib, pkgs, ... }: with lib; let cfg = config.purpose.gaming.roblox; in {
  options.purpose.gaming.roblox = {
    enable = mkEnableOption "Enable Roblox launcher";

    grapejuicePackage = mkOption {
      type = types.package;
      default = pkgs.unstable.grapejuice;
      description = "The package to use for Grapejuice";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.grapejuicePackage ];

    user.persistence.directories = [
      ".config/brinkervii/grapejuice"
      ".local/share/grapejuice"
    ];
  };
}
