{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    getExe'
    attrsOf
    nameValuePair
    hasAttrByPath
    listToAttrs
    imap1
    ;
  inherit (lib.types)
    str
    listOf
    enum
    anything
    submodule
    ;
  inherit (pkgs)
    uwsm
    writers
    pyprland
    ;

  cfg = config.wayland.windowManager.hyprland.custom-settings.slideIn;

  uwsmApp = getExe' uwsm "uwsm-app";

  commonOptions = {
    bind = mkOption {
      type = str;
      description = ''
        Key binding to trigger the slide-in popup.

        This is passed through to the lua config without checking for validity,
        the lua config will throw an error if the binding is invalid.
      '';
    };

    exec = mkOption {
      type = str;
      description = "Command to execute for the slide-in popup.";
    };

    class = mkOption {
      type = str;
      description = "Window class for the slide-in popup.";
    };

    size = mkOption {
      type = submodule {
        options = {
          width = mkOption {
            type = str;
            description = "Width of the slide-in popup. Can be specified as a percentage (e.g., '20%') or in pixels (e.g., '400px').";
          };
          height = mkOption {
            type = str;
            description = "Height of the slide-in popup. Can be specified as a percentage (e.g., '33%') or in pixels (e.g., '300px').";
          };
        };
      };
      default = { };
      description = "Size of the slide-in popup. Can specify 'width' and/or 'height'.";
    };

    extProp = mkOption {
      type = attrsOf anything;
      default = { };
      description = "Extra properties to pass to the scratchpad configuration in pyprland.";
    };

    position = mkOption {
      type = enum [
        "left"
        "right"
        "top"
        "bottom"
        # TODO: Implement edge routing and side routing
        # "edge"
        # "side"
      ];
      default = "top";
      description = "Direction from which the popup slides in.";
    };
  };

  isVerticalEdgeDefault = position: position == "edge" || position == "bottom" || position == "top";

  mkEntry = idx: app: {
    inherit (app)
      bind
      class
      exec
      size
      position
      extProp
      ;

    name = "slide-${toString idx}";
    width =
      if (hasAttrByPath [ "size" "width" ] app) && app.size.width != null then
        app.size.width
      else if isVerticalEdgeDefault app.position then
        "33%"
      else
        "20%";
    height =
      if (hasAttrByPath [ "size" "height" ] app) && app.size.height != null then
        app.size.height
      else if isVerticalEdgeDefault app.position then
        "33%"
      else
        "98%";
    animation =
      if app.position == "edge" || app.position == "side" then
        null
      else
        "from${lib.mine.strings.capitalise app.position}";
  };

  entries = imap1 mkEntry cfg;
  pyprConfig = writers.writeTOML "pyprlandConfig" {
    pyprland.plugins = [ "scratchpads" ];
    scratchpads =
      map (
        e:
        nameValuePair e.name (
          {
            inherit (e)
              name
              class
              position
              animation
              ;
            command = "${uwsmApp} -s b -- ${e.exec}";
            size = "${e.width} ${e.height}";
            lazy = true;
          }
          // e.extProp
        )
      ) entries
      |> listToAttrs;
  };

  slideInLuaConfig = lib.generators.toLua { } entries;
in
{
  options.wayland.windowManager.hyprland.custom-settings.slideIn = mkOption {
    default = [ ];
    type = listOf (submodule {
      options = commonOptions;
    });
    description = "List of slide-in popups that slide in from the edge of the screen.";
  };

  config = mkIf (cfg != [ ]) {
    home.packages = [ pyprland ];

    xdg.configFile."pypr/config.toml" = {
      source = pyprConfig;
      onChange = "${getExe' pyprland "pypr"} reload";
    };

    systemd.user.services.pyprland = {
      Install.WantedBy = [ config.wayland.systemd.target ];

      Unit = {
        Description = "Pyprland Hyprland plugin manager";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };

      Service = {
        ExecStart = getExe' pyprland "pypr";
        Restart = "on-failure";
        RestartSec = 5;
        Type = "simple";

        NoNewPrivileges = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectKernelTunables = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        ProtectSystem = "strict";
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectProc = "invisible";
        RemoveIPC = true;
      };
    };

    wayland.windowManager.hyprland.custom-settings.lua = {
      luaModules = [ ./lua/opt/slide_in.lua ];
      variables = {
        slideInConfig = slideInLuaConfig;
        pyprClient = getExe' pyprland "pypr-client";
      };
    };
  };
}
