{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.purpose.gaming.steam;
in
{
  options.purpose.gaming.steam = {
    enable = mkEnableOption "Steam";
  };

  config = mkIf cfg.enable {
    xdg.mimeApps = {
      defaultApplications."x-scheme-handler/steam" = "steam.desktop";
      associations.added."x-scheme-handler/steam" = "steam.desktop";
    };

    home = {
      activation.steam-setup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        STEAM="$HOME/.local/share/Steam"

        CEF_FILE="$STEAM/.cef-enable-remote-debugging"
        if [ ! -f $CEF_FILE ]; then
          touch $CEF_FILE
        fi

        DEV_CONFIG="$STEAM/steam_dev.cfg"
        CONTENTS=(
          "unShaderBackgroundProcessingThreads 8"
          "@nClientDownloadEnableHTTP2PlatformLinux 0"
          "@fDownloadRateImprovementToAddAnotherConnection 1.1"
          "@cMaxInitialDownloadSources 15"
        )
        for LINE in "''${CONTENTS[@]}"; do
          if ! grep -q "$LINE" $DEV_CONFIG; then
            echo "$LINE" >> $DEV_CONFIG
          fi
        done
      '';

      packages = with pkgs; [
        protonup-rs
        adwsteamgtk
      ];
    };

    systemd.user.tmpfiles.rules = [
      "L+ %h/.local/share/Steam/steamapps - - - - %h/Games/SteamLibrary"
    ];

    user.persistence = {
      files = [
        ".steam/registry.vdf"
      ];
      directories = [
        ".local/share/Steam"
        ".config/steamtinkerlaunch"
        ".config/AdwSteamGtk"

        # Games
        ".barony"
        ".local/share/Colossal Order/Cities_Skylines"
        ".config/WarThunder"
        ".config/Gaijin"
        ".config/unity3d/IronGate/Valheim"
        ".config/StardewValley"
        ".factorio"
      ];
    };
  };
}
