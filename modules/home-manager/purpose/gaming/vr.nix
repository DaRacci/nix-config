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
    };
    xdg = {
      configFile."openxr/1/active_runtime.json".source = "${pkgs.wivrn}/share/openxr/1/openxr_wivrn.json";
      configFile."openvr/openvrpaths.vrpath".text =
        let
          steam = "${config.xdg.dataHome}/Steam";
        in
        builtins.toJSON {
          version = 1;
          jsonid = "vrpathreg";
          external_drivers = null;
          config = [ "${steam}/config" ];
          log = [ "${steam}/logs" ];
          runtime = [ "${pkgs.xrizer}/lib/xrizer" ];
        };

      mimeApps = {
        defaultApplications = {
          "x-scheme-handler/vrmonitor" = "valve-URI-vrmonitor.desktop";
          "application/x-vrmonitor" = "valve-vrmonitor.desktop";
        };
        associations.added = {
          "x-scheme-handler/vrmonitor" = "valve-URI-vrmonitor.desktop";
          "application/x-vrmonitor" = "valve-vrmonitor.desktop";
        };
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
