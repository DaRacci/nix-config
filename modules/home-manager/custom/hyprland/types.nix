{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (types) nullOr float listOf enum ints either submodule percentString bool int str strMatching addCheck;
in
rec {
  percentString = addCheck (strMatching "^(-)?[0-9]{1,3}+(%)?$") (
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
      fullscreenState = mkOption {
        type = nullOr (submodule {
          options = {
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
              apply = toString;
            };
            y = mkOption {
              type = nullOr (either percentString int);
              default = null;
              description = "Move the window to the y coordinate.";
              apply = toString;
            };
          };
        });
        default = null;
        description = "Move the window.";
      };
      size = mkOption {
        type = nullOr (
          either str (
            either str (submodule {
              options = {
                width = mkOption {
                  type = nullOr (either percentString int);
                  default = null;
                  description = "Set the window width.";
                  apply = toString;
                };
                height = mkOption {
                  type = nullOr (either percentString int);
                  default = null;
                  description = "Set the window height.";
                  apply = toString;
                };
              };
            })
          )
        );
        default = null;
        apply = v: if builtins.isAttrs v then "${v.width} ${v.height}" else v;
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
      no_initial_focus = mkOption {
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
      noMaxSize = mkOption {
        type = nullOr bool;
        default = null;
        description = "removes max size limitations. Especially useful with windows that report invalid max sizes (e.g. winecfg)";
      };
      stayFocused = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces focus on the window as long as it's visible";
      };
      group = mkOption {
        type = nullOr str;
        default = null;
        description = "set window group properties.";
      };
      content = mkOption {
        type = nullOr str;
        default = null;
        description = "Sets content type.";
      };
      noCloseFor = mkOption {
        type = nullOr (either int str);
        default = null;
        description = "Makes the window uncloseable with the killactive dispatcher for a given amount of ms on open.";
        apply = toString;
      };
      #endregion

      #region Dynamic Rules
      # TODO - Animation, border colour,
      animation = mkOption {
        type = nullOr (listOf str);
        default = null;
        description = "sets the animations for the window. Can be a single animation or a comma separated list of animations. See the Animations page for more information.";
      };
      allowsInput = mkOption {
        type = nullOr bool;
        default = null;
        description = "Forces an XWayland window to receive input, even if it requests not to do so. (Might fix issues like Game Launchers not receiving focus for some reason)";
      };
      idleInhibit = mkOption {
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
      maxSize = mkOption {
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
      minSize = mkOption {
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
      borderSize = mkOption {
        type = nullOr int;
        default = null;
        description = "sets the border size";
      };
      rounding = mkOption {
        type = nullOr int;
        default = null;
        description = "forces the application to have X pixels of rounding, ignoring the set default (in decoration:rounding). Has to be an int.";
      };
      allowInput = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces an XWayland window to receive input, even if it requests not to do so. (Might fix issues like e.g. Game Launchers not receiving focus for some reason)";
      };
      dimAround = mkOption {
        type = nullOr bool;
        default = null;
        description = "dims everything around the window . Please note this rule is meant for floating windows and using it on tiled ones may result in strange behavior.";
      };
      decorate = mkOption {
        type = nullOr bool;
        default = null;
        description = "whether to draw window decorations or not";
      };
      focusOnActive = mkOption {
        type = nullOr bool;
        default = null;
        description = "whether Hyprland should focus an app that requests to be focused (an activate request)";
      };
      keepAspectRatio = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces aspect ratio when resizing window with the mouse";
      };
      nearestNeighbor = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces the window to use the nearest neighbor filtering.";
      };
      noAnimation = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables the animations for the window";
      };
      noBlur = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables blur for the window";
      };
      noDim = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables window dimming for the window";
      };
      noFocus = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables focus to the window";
      };
      noRounding = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables rounding for the window";
      };
      noShadow = mkOption {
        type = nullOr bool;
        default = null;
        description = "disables shadows for the window";
      };
      noShotcutsInhibit = mkOption {
        type = nullOr bool;
        default = null;
        description = "disallows the app from inhibiting your shortcuts";
      };
      noScreenShare = mkOption {
        type = nullOr bool;
        default = null;
        description = "Hides the window and its popups from screen sharing by drawing black rectangles in their place. The rectangles are drawn even if other windows are above.";
      };
      opaque = mkOption {
        type = nullOr bool;
        default = null;
        description = "forces the window to be opaque";
      };
      forceRgbx = mkOption {
        type = nullOr bool;
        default = null;
        description = "makes Hyprland ignore the alpha channel of all the window's surfaces, effectively making it actually, fully 100% opaque";
      };
      syncFullscreen = mkOption {
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
      renderUnfocused = mkOption {
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
      float = mkOption {
        type = nullOr bool;
        default = null;
        description = "Floating windows.";
      };
      fullscreen = mkOption {
        type = nullOr bool;
        default = null;
        description = "Fullscreen windows.";
      };
      pin = mkOption {
        type = nullOr bool;
        default = null;
        description = "Pinned windows.";
      };
      focus = mkOption {
        type = nullOr bool;
        default = null;
        description = "Currently focused window.";
      };
      group = mkOption {
        type = nullOr bool;
        default = null;
        description = "Grouped windows.";
      };
      modal = mkOption {
        type = nullOr bool;
        default = null;
        description = "Modal windows (e.g. “Are you sure” popups)";
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
      workspace = mkOption {
        type = nullOr (submodule workspaceSelector);
        default = null;
        description = "Windows on matching workspace.";
      };
      content = mkOption {
        type = nullOr int;
        default = null;
        description = "Windows with specified content type (none = 0, photo = 1, video = 2, game = 3)";
      };
      xdg_tag = mkOption {
        type = nullOr str;
        default = null;
        description = "Match a window by its xdgTag (see hyprctl clients to check if it has one)";
      };
    };
  };
}
