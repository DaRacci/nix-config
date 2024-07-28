{ config, pkgs, lib, ... }:
let cfg = config.purpose.gaming.vr; in {
  options.purpose.gaming.vr = {
    enable = lib.mkEnableOption "Enable VR support";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ sidequest oscavmgr ];

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

    home.activation.link-steamvr-openxr-runtime = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p $VERBOSE_ARG \
        "$HOME/.config/openxr/1/";

      run ln -s $VERBOSE_ARG \
        "$HOME/.config/openxr/1/active_runtime.json" "$HOME/.steam/steam/steamapps/common/SteamVR/steamxr_linux64.json";
    '';

    user.persistence.directories = [
      ".config/alvr"
    ];
  };
}
