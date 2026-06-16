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

  uwsmCommand = exe: "${lib.getExe' pkgs.uwsm "uwsm-app"} -s a -- ${exe}";

  toStartupCmd =
    exe:
    if builtins.isString exe then
      uwsmCommand exe
    else if builtins.isAttrs exe then
      "${
        if exe ? options then "[${builtins.concatStringsSep ";" exe.options}] " else ""
      }${uwsmCommand exe.executable}"
    else
      null;

  mkWorkspaceEntry =
    id: value:
    {
      workspace = id;
      persistent = true;
    }
    // (lib.optionalAttrs (value.name != null) {
      default_name = value.name;
    })
    // (lib.optionalAttrs (value.monitor != null) {
      monitor = value.monitor;
    })
    // (lib.optionalAttrs ((value.startup or [ ]) != [ ]) {
      on_created_empty = builtins.concatStringsSep " && " (map toStartupCmd value.startup);
    })
    // (value.extraRules or { });
in
{
  wayland.windowManager.hyprland.settings.workspace_rule =
    lib.mapAttrsToList mkWorkspaceEntry workspaces;
}
