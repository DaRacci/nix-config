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

    user.persistence.directories = [
      ".config/alvr"
    ];
  };
}
