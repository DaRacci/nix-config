{ config, lib, ... }:
with lib.types;
let
  inherit (lib) mkOption;
  cfg = config.wayland.windowManager.hyprland.custom-settings;

  percentString = types.addCheck (strMatching "^(-)?[0-9]{1,3}+(%)?$") (
    str:
    let
      isPercent = lib.strings.hasSuffix "%" str;
      num = lib.toInt (if isPercent then lib.strings.removeSuffix "%" str else str);
    in
    if isPercent then num >= -100 && num <= 100 else true
  );

  monitorSelector = _: {
    options = {
      name = mkOption {
        type = nullOr str;
        default = null;
        description = "Monitor name.";
      };
      index = mkOption {
        type = nullOr int;
        default = null;
        description = "Monitor index.";
      };
    };
  };

  workspaceSelector = _: {
    options = {
      id = mkOption {
        type = nullOr int;
        default = null;
        description = "Workspace id.";
      };
      relativeId = mkOption {
        type = nullOr int;
        default = null;
        description = "Workspace relative id.";
      };
      name = mkOption {
        type = nullOr str;
        default = null;
        description = "Workspace name.";
      };
      special = mkOption {
        type = nullOr (either int str);
        default = null;
        description = "Special workspace. Can be id or name.";
      };
    };
  };

  rule = _: {
    options = {
      #region Static Rules
      float = mkOption {
        type = nullOr bool;
        default = null;
        description = "Float the window.";
      };
      tile = mkOption {
        type = nullOr bool;
        default = null;
        description = "Tile the window.";
      };
      fullscreen = mkOption {
        type = nullOr bool;
        default = null;
        description = "Fullscreen the window.";
      };
      maximize = mkOption {
        type = nullOr bool;
        default = null;
        description = "Maximize the window.";
      };
      fullscreenstate = mkOption {
        type = nullOr (submodule {
          internal = mkOption {
            type = with types; either (enum [ "*" ]) ints.between 0 3;
            default = null;
            description = "Set the internal fullscreen state. internal can be * - any, 0 - none, 1 - maximize, 2 - fullscreen, 3 - maximize and fullscreen.";
          };
          client = mkOption {
            type = with types; either (enum [ "*" ]) ints.between 0 3;
            default = null;
            description = "Set the client fullscreen state. client can be * - any, 0 - none, 1 - maximize, 2 - fullscreen, 3 - maximize and fullscreen.";
          };
        });
        default = null;
        description = "Set the fullscreen state. internal and client can be * - any, 0 - none, 1 - maximize, 2 - fullscreen, 3 - maximize and fullscreen.";
      };
      move = mkOption {
        type = nullOr (submodule {
          options = {
            x = mkOption {
              type = nullOr (either percentString int);
              default = null;
              description = "Move the window to the x coordinate.";
              apply = x: toString x;
            };
            y = mkOption {
              type = nullOr (either percentString int);
              default = null;
              description = "Move the window to the y coordinate.";
              apply = x: toString x;
            };
          };
        });
        default = null;
        description = "Move the window.";
      };
      size = mkOption {
        type = nullOr (
          either str (submodule {
            options = {
              width = mkOption {
                type = nullOr int;
                default = null;
                description = "Set the window width.";
              };
              height = mkOption {
                type = nullOr int;
                default = null;
                description = "Set the window height.";
              };
            };
          })
        );
        default = null;
        description = "Set the window size.";
      };
      center = mkOption {
        type = nullOr (
          either bool (submodule {
            options = {
              center = mkOption {
                type = nullOr bool;
                default = null;
                description = "Center the window.";
              };
              respectReservedArea = mkOption {
                type = nullOr bool;
                default = null;
                description = "Respect monitor reserved area.";
              };
            };
          })
        );
        default = null;
        description = "Center the window.";
      };
      pseudo = mkOption {
        type = nullOr bool;
        default = null;
        description = "Pseudo tile window.";
      };
      monitor = mkOption {
        type = nullOr (submodule monitorSelector);
        default = null;
        description = "Move the window to the monitor.";
      };
      workspace = mkOption {
        type = nullOr (submodule workspaceSelector);
        default = null;
        description = "Move the window to the workspace. Can be id or name.";
      };
      noinitialfocus = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables the initial focus to the window";
      };
      pin = mkOption {
        type = nullOr bool;
        default = null;
        description = "pins the window (i.e. show it on all workspaces) note: floating only";
      };
      unset = mkOption {
        type = nullOr bool;
        default = null;
        description = "removes all previously set rules for the given parameters. Please note it has to match EXACTLY.";
      };
      nomaxsize = mkOption {
        type = nullOr bool;
        default = null;
        description = "removes max size limitations. Especially useful with windows that report invalid max sizes (e.g. winecfg)";
      };
      stayfocused = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces focus on the window as long as it's visible";
      };
      group = mkOption {
        type = nullOr str;
        default = null;
        description = "set window group properties.";
      };
      #endregion

      #region Dynamic Rules
      # TODO - Animation, border colour,
      idleinhibit = mkOption {
        type = nullOr (enum [
          "none"
          "always"
          "focus"
          "fullscreen"
        ]);
        default = null;
        description = "sets an idle inhibit rule for the window. If active, apps like hypridle will not fire. Modes: none, always, focus, fullscreen";
      };
      opacity = mkOption {
        type = nullOr (
          either float (submodule {
            options = {
              activeopacity = mkOption {
                type = nullOr float;
                default = null;
                description = "Active opacity.";
              };

              inactiveopacity = mkOption {
                type = nullOr float;
                default = null;
                description = "Inactive opacity.";
              };

              additionalopacity = mkOption {
                type = nullOr float;
                default = null;
                description = "Additional opacity multiplier.";
              };
            };
          })
        );
        default = null;
        description = "Additional opacity multiplier.";
      };
      tag = mkOption {
        type = nullOr str;
        default = null;
        description = "Apply tag to the window, use prefix +/- to set/unset flag, or no prefix to toggle the flag";
      };
      maxsize = mkOption {
        type = nullOr (submodule {
          options = {
            width = mkOption {
              type = nullOr int;
              default = null;
              description = "Set the window max width.";
            };
            height = mkOption {
              type = nullOr int;
              default = null;
              description = "Set the window max height.";
            };
          };
        });
        default = null;
        description = "Set the window max size.";
      };
      minsize = mkOption {
        type = nullOr (submodule {
          options = {
            width = mkOption {
              type = nullOr int;
              default = null;
              description = "Set the window min width.";
            };
            height = mkOption {
              type = nullOr int;
              default = null;
              description = "Set the window min height.";
            };
          };
        });
        default = null;
        description = "Set the window min size.";
      };
      bordersize = mkOption {
        type = nullOr int;
        default = null;
        description = "sets the border size";
      };
      rounding = mkOption {
        type = nullOr int;
        default = null;
        description = "forces the application to have X pixels of rounding, ignoring the set default (in decoration:rounding). Has to be an int.";
      };
      allowinput = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces an XWayland window to receive input, even if it requests not to do so. (Might fix issues like e.g. Game Launchers not receiving focus for some reason)";
      };
      dimaround = mkOption {
        type = nullOr bool;
        default = null;
        description = "dims everything around the window . Please note this rule is meant for floating windows and using it on tiled ones may result in strange behavior.";
      };
      decorate = mkOption {
        type = nullOr bool;
        default = null;
        description = "whether to draw window decorations or not";
      };
      focusonactive = mkOption {
        type = nullOr bool;
        default = null;
        description = "whether Hyprland should focus an app that requests to be focused (an activate request)";
      };
      keepaspectratio = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces aspect ratio when resizing window with the mouse";
      };
      nearestneighbor = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces the window to use the nearest neighbor filtering.";
      };
      noanimation = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables the animations for the window";
      };
      noblur = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables blur for the window";
      };
      noborder = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables borders for the window";
      };
      nodim = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables window dimming for the window";
      };
      nofocus = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables focus to the window";
      };
      norounding = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables rounding for the window";
      };
      noshadow = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables shadows for the window";
      };
      noshotcutsinhibit = mkOption {
        type = nullOr bool;
        default = null;
        description = "disallows the app from inhibiting your shortcuts";
      };
      opaque = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces the window to be opaque";
      };
      forcergbx = mkOption {
        type = nullOr bool;
        default = null;
        description = "makes Hyprland ignore the alpha channel of all the window's surfaces, effectively making it actually, fully 100% opaque";
      };
      syncfullscreen = mkOption {
        type = nullOr bool;
        default = null;
        description = "whether the fullscreen mode should always be the same as the one sent to the window (will only take effect on the next fullscreen mode change)";
      };
      immediate = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces the window to allow to be torn. See the Tearing page.";
      };
      xray = mkOption {
        type = nullOr bool;
        default = null;
        description = "sets blur xray mode for the window";
      };
      renderunfocused = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces the window to think it's being rendered when it's not visible - see also Variables - Misc for setting render_unfocused_fps";
      };
      #endregion
    };
  };

  windowMatch = _: {
    options = {
      class = mkOption {
        type = nullOr str;
        default = null;
        description = "Windows with class matching regex.";
      };
      title = mkOption {
        type = nullOr str;
        default = null;
        description = "Windows with title matching regex.";
      };
      initialClass = mkOption {
        type = nullOr str;
        default = null;
        description = "Windows with initialClass matching regex.";
      };
      initialTitle = mkOption {
        type = nullOr str;
        default = null;
        description = "Windows with initialTitle matching regex.";
      };
      tag = mkOption {
        type = nullOr str;
        default = null;
        description = "Windows with matching tag.";
      };
      xwayland = mkOption {
        type = nullOr bool;
        default = null;
        description = "Xwayland windows.";
      };
      floating = mkOption {
        type = nullOr bool;
        default = null;
        description = "Floating windows.";
      };
      fullscreen = mkOption {
        type = nullOr bool;
        default = null;
        description = "Fullscreen windows.";
      };
      pinned = mkOption {
        type = nullOr bool;
        default = null;
        description = "Pinned windows.";
      };
      focus = mkOption {
        type = nullOr bool;
        default = null;
        description = "Currently focused window.";
      };
      fullscreenstate = mkOption {
        type = nullOr (submodule {
          options = {
            internal = mkOption {
              type = nullOr (either (enum [ "*" ]) ints.between 0 3);
              default = null;
              description = "The internal fullscreen state, * - any, 0 - none, 1 - maximize, 2 - fullscreen, 3 - maximize and fullscreen.";
            };
            client = mkOption {
              type = nullOr (either (enum [ "*" ]) ints.between 0 3);
              default = null;
              description = "The client fullscreen state, * - any, 0 - none, 1 - maximize, 2 - fullscreen, 3 - maximize and fullscreen.";
            };
          };
        });
        default = null;
        description = "Windows with matching fullscreenstate. internal and client can be * - any, 0 - none, 1 - maximize, 2 - fullscreen, 3 - maximize and fullscreen.";
      };
      onworkspace = mkOption {
        type = nullOr (submodule workspaceSelector);
        default = null;
        description = "Windows on matching workspace.";
      };
    };
  };

  mkWindowRuleV2 =
    obj:
    let
      inherit (obj) rule;
      nonNullRules = lib.filterAttrs (_: v: v != null) rule;

      matchers = if builtins.typeOf obj.matcher == "list" then obj.matcher else [ obj.matcher ];

      getMatcherValue =
        _name: value: if (builtins.typeOf value == "bool") then if value then "1" else "0" else value;

      mkRuleString =
        name: value:
        if builtins.typeOf value == "bool" then
          name
        else if builtins.typeOf value == "set" then
          "${name} ${lib.concatStringsSep " " (lib.mapAttrsToList (_name: toString) value)}"
        else
          "${name} ${toString value}";

      mkMatcherString =
        matcher:
        let
          nonNullMatchers = lib.filterAttrs (_: v: v != null) matcher;
        in
        if builtins.length (builtins.attrValues nonNullMatchers) == 0 then
          throw "At least one matcher must be set."
        else
          lib.concatStringsSep "," (
            lib.mapAttrsToList (name: value: "${name}:${getMatcherValue name value}") nonNullMatchers
          );

      matcherStrings = builtins.map mkMatcherString matchers;
      ruleStrings = lib.mapAttrsToList mkRuleString nonNullRules;
    in
    lib.pipe matcherStrings [
      # Create a list of rule strings for each matcher.
      (lib.map (matcher: lib.pipe ruleStrings [ (lib.map (ruleString: "${ruleString}, ${matcher}")) ]))
    ];

in
# lib.trivial.pipe nonNullRules [
#   (lib.mapAttrsToList (name: value: lib.concatStringsSep "," [
#     "${mkRuleString name value}"
#     matcherString
#   ]))
# ];
{
  options.wayland.windowManager.hyprland.custom-settings = {
    windowrule = mkOption {
      type =
        with types;
        listOf (submodule {
          options = {
            matcher = mkOption {
              type = either (submodule windowMatch) (listOf (submodule windowMatch));
            };
            rule = mkOption { type = submodule rule; };
          };
        });
      default = [ ];
      description = "Match rules for windows.";
    };
  };

  config = {
    wayland.windowManager.hyprland.settings = {
      windowrulev2 = lib.pipe cfg.windowrule [
        (builtins.map mkWindowRuleV2)
        lib.flatten
      ];
    };
  };
}
