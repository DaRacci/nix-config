{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    types
    concatStringsSep
    optionalString
    ;
  inherit (types)
    anything
    attrsOf
    bool
    listOf
    nullOr
    oneOf
    str
    ;

  cfg = config.wayland.windowManager.hyprland.custom-settings.workspaces;

  workspaceDefType = types.submodule {
    options = {
      name = mkOption {
        type = nullOr str;
        default = null;
        description = "Workspace default name.";
      };

      monitor = mkOption {
        type = nullOr str;
        default = null;
        description = "Monitor to assign workspace on startup.";
      };

      startup = mkOption {
        type = listOf (oneOf [
          str
          (attrsOf str)
        ]);
        default = [ ];
        description = "Commands to run when workspace is first created empty.";
      };

      extraRules = mkOption {
        type = attrsOf anything;
        default = { };
        description = "Additional workspace rule properties to pass to `workspace_rule()`.";
      };
    };
  };

  uwsmCommand = exe: "${lib.getExe' pkgs.uwsm "uwsm-app"} -s a -- ${exe}";

  toStartupCmd =
    exe:
    if builtins.isString exe then
      uwsmCommand exe
    else if builtins.isAttrs exe then
      "${
        if exe ? options then "[${concatStringsSep ";" exe.options}] " else ""
      }${uwsmCommand exe.executable}"
    else
      null;

  workspaceLuaTable = lib.generators.toLua { } (
    lib.mapAttrs (_id: value: {
      name = optionalString (value.name != null) value.name;
      monitor = value.monitor or null;
      cmds = optionalString ((value.startup or [ ]) != [ ]) (
        concatStringsSep " && " (map toStartupCmd value.startup)
      );
    }) cfg.definitions
  );

in
{
  options.wayland.windowManager.hyprland.custom-settings.workspaces = {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Enable workspace configuration module.";
    };

    definitions = mkOption {
      type = attrsOf workspaceDefType;
      default = { };
      description = "Workspace definitions by ID";
    };
  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.custom-settings.lua = {
      variables.workspaceConfig = workspaceLuaTable;
      luaModules = [ ./lua/opt/workspaces.lua ];
    };
  };
}
