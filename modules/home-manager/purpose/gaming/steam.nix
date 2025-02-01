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
      activation.decky-loader-enabler = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        FILE="$HOME/.local/share/Steam/.cef-enable-remote-debugging"

        if [ -f $FILE ]; then
          echo "CEF Remote Debugging already enabled"
        else
          echo "Enabling CEF Remote Debugging"
          touch $FILE
        fi
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
        {
          directory = ".local/share/Steam";
          method = "symlink";
        }
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
