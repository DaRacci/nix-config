{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.gaming.vr;
in
{
  options.purpose.gaming.vr = {
    enable = lib.mkEnableOption "Enable VR support";
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        sidequest
        oscavmgr
        vrcadvert
        android-tools
      ];

      file.".config/alvr/alvr-startup.sh" = {
        executable = true;
        source = pkgs.writeShellApplication {
          name = "alvr-startup.sh";
          runtimeInputs = [
            pkgs.vrcadvert
            pkgs.oscavmgr
          ];
          text = ''
            trap 'jobs -p | xargs kill' EXIT

            runtimeInputs 9402 9002 &
            oscavmgr alvr
          '';
        };
      };

      file.".config/alvr/alvr-stop.sh" = {
        executable = true;
        text = ''
          killall VrcAdvert
          killall oscavmgr
        '';
      };

      activation.link-steamvr-openxr-runtime = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        RUNTIME_PATH="$HOME/.config/openxr/1/active_runtime.json"

        run mkdir -p $VERBOSE_ARG \
          "$HOME/.config/openxr/1/";

        if [ -L "$RUNTIME_PATH" ]; then
          run rm $VERBOSE_ARG \
            "$RUNTIME_PATH";
        fi

        run ln -s $VERBOSE_ARG \
          "$HOME/.local/share/Steam/steamapps/common/SteamVR/steamxr_linux64.json" "$RUNTIME_PATH";
      '';
    };

    xdg.mimeApps = {
      defaultApplications = {
        "x-scheme-handler/vrmonitor" = "valve-URI-vrmonitor.desktop";
        "application/x-vrmonitor" = "valve-vrmonitor.desktop";
      };
      associations.added = {
        "x-scheme-handler/vrmonitor" = "valve-URI-vrmonitor.desktop";
        "application/x-vrmonitor" = "valve-vrmonitor.desktop";
      };
    };

    user.persistence.directories = [
      ".config/alvr"
      ".android"
      ".SideQuest"
      ".config/wivrn"
    ];
  };
}
