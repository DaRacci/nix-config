# TODO - Force restart steam on rebuild if its open
# TODO - Block switch if steam has game open
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
    enableNvidiaPatches = (mkEnableOption "Enable Nvidia patches") // {
      description = ''
        Enabled a script which applies a patch to the steam runtime shel file to allow gpu acceleration on nvidia cards.
      '';
    };
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
      ];
    };
  };
}
