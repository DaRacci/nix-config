{
  config,
  pkgs,
  lib,
  ...
}:
let
  monitors = {
    left = "DP-1";
    center = "DP-2";
    right = "DP-3";
  };

  workspaces = {
    "1" = {
      name = "Terminal";
      monitor = monitors.center;
      startup = [ (lib.getExe pkgs.alacritty) ];
    };
    "2" = {
      name = "Browser";
      monitor = monitors.left;
      startup = [ (lib.getExe config.programs.firefox.package) ];
    };
    "3" = {
      name = "Files & Knowledge";
      monitor = monitors.left;
      startup = [ (lib.getExe pkgs.obsidian) ];
    };
    "4" = {
      name = "Social";
      monitor = monitors.center;
      startup = [ (lib.getExe pkgs.discord) ];
    };
    "5" = {
      name = null;
      monitor = monitors.right;
    };
    "6" = {
      name = "Media";
      monitor = monitors.center;
    };
    "7" = {
      name = "Development";
      monitor = monitors.center;
      startup = [ (lib.getExe config.programs.zed-editor.package) ];
    };
    "8" = {
      name = "Gaming";
      monitor = monitors.left;
      startup = [ "steam.desktop" ];
    };
    "9" = {
      name = "Miscellaneous";
      monitor = monitors.left;
      startup = [ (lib.getExe pkgs.spotify) ];
    };
    "10" = {
      name = "Miscellaneous";
      monitor = monitors.left;
    };
  };
in
{
  wayland.windowManager.hyprland.settings = {
    workspace =
      # [
      #   "1, on-created-empty:alacritty"

      # "3, rounding:false, decorate:false"
      # "name:coding, rounding:false, decorate:false, gapsin:0, gapsout:0, border:false, monitor:DP-1"
      # "8,bordersize:8"
      # "name:Hello, monitor:DP-1, default:true"
      # "name:gaming, monitor:desc:Chimei Innolux Corporation 0x150C, default:true"
      # "5, on-created-empty:[float] firefox"
      # "special:scratchpad, on-created-empty:alacritty"
      # ]
      lib.mapAttrsToList (
        id: value:
        let
          assignNotNull = key: value: if value != null then key + ":" + value else null;
          uwsmCommand = exe: "${lib.getExe' pkgs.uwsm "uwsm-app"} -s a -- ${exe}";
          executableToCommand =
            exe:
            if builtins.isString exe then
              uwsmCommand exe
            else if builtins.isAttrs exe then
              "${
                if exe ? options then "[${builtins.concatStringsSep ";" exe.options}]" else ""
              } ${uwsmCommand exe.executable}"
            else
              null;
          args = builtins.filter (v: v != null) [
            id
            (assignNotNull "defaultName" value.name)
            (assignNotNull "monitor" value.monitor)
            (assignNotNull "" (
              builtins.concatStringsSep ";" (builtins.map executableToCommand value.startup or [ ])
            ))
          ];
        in
        builtins.concatStringsSep "," args
      ) workspaces;
  };
}
