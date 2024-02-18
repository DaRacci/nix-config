# TODO - Only install if satisfactory is installed on steam
# Provides a general area for modding packages,
# and their persistent directories.
{ config, pkgs, lib, ... }: with lib; let cfg = config.purpose.gaming.modding; in {
  options.purpose.gaming.modding = {
    enable = mkEnableOption "Enable modding support";
    enableSatisfactory = mkEnableOption "Enable satisfactory modding support";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
    ] ++ (optionals cfg.enableSatisfactory [
      ficsit-cli
    ]);

    user.persistence.directories = [
    ] ++ (optionals cfg.enableSatisfactory [
      ".local/share/ficsit"
    ]);
  };
}
