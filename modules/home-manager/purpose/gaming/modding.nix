{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.purpose.gaming.modding;
in
{
  options.purpose.gaming.modding = {
    enable = mkEnableOption "Enable modding support";
    enableSatisfactory = mkEnableOption "Enable satisfactory modding support";
    enableBeatSaber = mkEnableOption "Enable beatsaber modding support";
    enableThunderstore = mkEnableOption "Enable thunderstore support";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      (optional cfg.enableSatisfactory ficsit-cli)
      ++ (optional cfg.enableBeatSaber bs-manager)
      ++ (optionals cfg.enableThunderstore [
        # gale
        r2modman
      ]);

    user.persistence.directories =
      (optional cfg.enableSatisfactory ".local/share/ficsit")
      ++ (optionals cfg.enableBeatSaber [
        ".config/bs-manager"
        ".local/share/BSManager"
      ])
      ++ (optionals cfg.enableThunderstore [
        ".config/r2modman"
        ".config/r2modmanPlus-local"
        ".config/com.kesomannen.gale"
        ".local/share/com.kesomannen.gale"
      ]);
  };
}
