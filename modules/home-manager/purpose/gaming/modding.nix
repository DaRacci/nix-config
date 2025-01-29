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
    enableNexus = mkEnableOption "Enable nexus mod manager support";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      (optional cfg.enableSatisfactory ficsit-cli)
      ++ (optional cfg.enableBeatSaber beatsabermodmanager)
      ++ (optionals cfg.enableThunderstore [
        gale
        r2modman
      ])
      ++ (optional cfg.enableNexus (nexusmods-app.override { _7zz = _7zz-rar; }));

    xdg.mimeApps.defaultApplications = mkIf cfg.enableBeatSaber {
      "x-scheme-handler/beatsaver" = "BeatSaberModManager-url-beatsaver.desktop";
      "x-scheme-handler/modelsaber" = "BeatSaberModManager-url-modelsaber.desktop";
      "x-scheme-handler/bsplaylist" = "BeatSaberModManager-url-bsplaylist.desktop";
    };

    user.persistence.directories =
      (optional cfg.enableSatisfactory ".local/share/ficsit")
      ++ (optional cfg.enableBeatSaber ".config/BeatSaberModManager")
      ++ (optionals cfg.enableThunderstore [
        ".config/r2modman"
        ".config/r2modmanPlus-local"
        ".config/com.kesomannen.gale"
        ".local/share/com.kesomannen.gale"
      ])
      ++ (optional cfg.enableNexus ".local/share/NexusMods.App");
  };
}
