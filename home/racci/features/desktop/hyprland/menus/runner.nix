{
  config,
  lib,
  ...
}:
{
  xdg.configFile."rofi/runner.rasi".text = ''
    @import "~/.config/rofi/config.rasi"

    // Config //
    configuration {
      modi:                        "drun,calc,window,run";
      matching:                    "fuzzy";
      show-icons:                  true;
      display-drun:                " ";
      display-calc:                " ";
      display-run:                 " ";
      display-window:              " ";
      drun-display-format:         "{name}";
      window-format:               "{w}{t}";
    }

    // Main //
    window {
      fullscreen:                  false;
      enabled:                     true;
      cursor:                      "default";
    }
    mainbox {
      enabled:                     true;
      spacing:                     0em;
      padding:                     0em;
      orientation:                 vertical;
      children:                    [ "inputbar" , "listbox" , "mode-switcher" ];
      background-color:            transparent;
    }

    // Inputs //
    inputbar {
      enabled:                     true;
      children:                    [ "entry" ];
    }
    entry {
      enabled:                     true;
      padding:                     1em;
      spacing:                     0em;
      horizontal-align:            0.5;
      vertical-align:              0.5;

      placeholder:                 "Type to search...";
      blink:                       true;
    }

    // Lists //
    listbox {
      padding:                     0em;
      spacing:                     0em;
      orientation:                 horizontal;
      children:                    [ "listview" ];
      background-color:            transparent;
      background-image:            url("~/.local/share/wallpaper.quad", width);
    }
    listview {
      padding:                     2em;
      spacing:                     1em;
      enabled:                     true;
      columns:                     5;
      cycle:                       true;
      dynamic:                     true;
      scrollbar:                   false;
      layout:                      vertical;
      reverse:                     false;
      fixed-height:                true;
      fixed-columns:               true;
      cursor:                      "default";
    }

    // Modes //
    mode-switcher {
      orientation:                 horizontal;
      enabled:                     true;
      padding:                     2em 9.8em 2em 9.8em;
      spacing:                     2em;
      background-color:            transparent;
    }
    button {
      cursor:                      pointer;
      padding:                     2.5em;
      spacing:                     0em;
      border-radius:               3em;
    }

    // Elements //
    element {
      orientation:                 vertical;
      enabled:                     true;
      spacing:                     0.2em;
      padding:                     0.5em;
      cursor:                      pointer;
      background-color:            transparent;
      border-radius:               ${
        toString (config.wayland.windowManager.hyprland.settings.decoration.rounding * 2)
      };
    }
    element-icon {
      size:                        5.5em;
      cursor:                      inherit;
      background-color:            transparent;
    }
    element-text {
      vertical-align:              0.5;
      horizontal-align:            0.5;
      cursor:                      inherit;
      background-color:            transparent;
    }

    // Error message //
    error-message {
      text-transform:              capitalize;
      children:                    [ "textbox" ];
    }

    textbox {
      text-color:                  inherit;
      background-color:            inherit;
      vertical-align:              0.5;
      horizontal-align:            0.5;
    }
  '';

  wayland.windowManager.hyprland.extraConfig = ''
    bind=CTRL_ALT,SPACE,exec,${lib.getExe config.programs.rofi.finalPackage} -config ~/.config/rofi/runner.rasi -show drun
  '';
}
