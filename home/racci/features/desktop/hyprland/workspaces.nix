{
  config,
  pkgs,
  lib,
  ...
}:
let
  monitors = {
    left = "DP-1";
    center = "DP-6";
    right = "HDMI-A-1";
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
      extraRules = {
        rounding = "false";
        shadow = "false";
      };
    };
    "9" = {
      name = "Miscellaneous";
      monitor = monitors.left;
      startup = [ (lib.getExe pkgs.feishin) ];
    };
    "10" = {
      name = "Miscellaneous";
      monitor = monitors.left;
    };
  };
in
{
  wayland.windowManager.hyprland.settings = {
    workspace = lib.mapAttrsToList (
      id: value:
      let
        assignNotNull =
          key: value:
          if (value != null && (builtins.stringLength value > 0)) then key + ":" + value else null;
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
        args =
          builtins.filter (v: v != null) [
            id
            (assignNotNull "defaultName" value.name)
            (assignNotNull "monitor" value.monitor)
            (assignNotNull "on-created-empty" (
              builtins.concatStringsSep "&&" (builtins.map executableToCommand value.startup or [ ])
            ))
          ]
          ++ (lib.mapAttrsToList (k: v: "${k}:${v}") (value.extraRules or { }));
      in
      builtins.concatStringsSep "," args
    ) workspaces;
  };
}
