{ config, pkgs, lib, ... }: with lib; let cfg = config.purpose.gaming.modding; in {
  options.purpose.gaming.modding = {
    enable = mkEnableOption "Enable modding support";
    enableSatisfactory = mkEnableOption "Enable satisfactory modding support";
    enableBeatSaber = mkEnableOption "Enable beatsaber modding support";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs;
      (optional cfg.enableSatisfactory ficsit-cli);
    # ++ (optional cfg.enableBeatSaber beatsabermodmanager);

    xdg.mimeApps.defaultApplications = mkIf cfg.enableBeatSaber {
      "x-scheme-handler/beatsaver" = "BeatSaberModManager-url-beatsaver.desktop";
      "x-scheme-handler/modelsaber" = "BeatSaberModManager-url-modelsaber.desktop";
      "x-scheme-handler/bsplaylist" = "BeatSaberModManager-url-bsplaylist.desktop";
    };

    user.persistence.directories = optionals cfg.enableSatisfactory [
      ".local/share/ficsit"
      ".config/BeatSaberModManager"
    ];
  };
}
