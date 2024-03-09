{ lib, ... }: {
  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/Console" = {
      font-scale = 1.6;
    };

    "org/gnome/desktop/interface" = {
      clock-format = "24h";
      clock-show-date = true;
      clock-show-seconds = true;
      clock-show-weekday = true;
      color-scheme = "prefer-dark";
      cursor-size = 32;
      cursor-theme = "Bibata-Modern-Ice";
      enable-hot-corners = false;
      font-name = "Fira Sans 12";
      gtk-enable-primary-paste = false;
      gtk-theme = "Adwaita-dark";
      icon-theme = "Adwaita";
      toolkit-accessibility = false;
    };

    "org/gnome/desktop/peripherals/mouse" = {
      accel-profile = "flat";
    };

    "org/gnome/desktop/session" = {
      idle-delay = mkUint32 300;
    };

    "org/gnome/desktop/wm/keybindings" = {
      active-window-menu = [ ];
      always-on-top = [ ];
      begin-move = [ ];
      begin-resize = [ ];
      close = [ "<Super>q" ];
      cycle-group = [ ];
      cycle-group-backward = [ ];
      cycle-panels = [ ];
      cycle-panels-backward = [ ];
      cycle-windows = [ ];
      cycle-windows-backward = [ ];
      lower = [ ];
      maximize = [ ];
      maximize-horizontally = [ ];
      maximize-vertically = [ ];
      minimize = [ ];
      move-to-center = [ ];
      move-to-corner-ne = [ ];
      move-to-corner-nw = [ ];
      move-to-corner-se = [ ];
      move-to-corner-sw = [ ];
      move-to-monitor-down = [ ];
      move-to-monitor-left = [ ];
      move-to-monitor-right = [ ];
      move-to-monitor-up = [ ];
      move-to-side-e = [ ];
      move-to-side-n = [ ];
      move-to-side-s = [ ];
      move-to-side-w = [ ];
      move-to-workspace-1 = [ ];
      move-to-workspace-10 = [ ];
      move-to-workspace-11 = [ ];
      move-to-workspace-12 = [ ];
      move-to-workspace-2 = [ ];
      move-to-workspace-3 = [ ];
      move-to-workspace-4 = [ ];
      move-to-workspace-5 = [ ];
      move-to-workspace-6 = [ ];
      move-to-workspace-7 = [ ];
      move-to-workspace-8 = [ ];
      move-to-workspace-9 = [ ];
      move-to-workspace-down = [ ];
      move-to-workspace-last = [ ];
      move-to-workspace-left = [ ];
      move-to-workspace-right = [ ];
      panel-main-menu = [ ];
      panel-run-dialog = [ "<Alt>F2" ];
      raise = [ ];
      raise-or-lower = [ ];
      set-spew-mark = [ ];
      show-desktop = [ ];
      switch-applications = [ "<Alt>Tab" ];
      switch-applications-backward = [ "<Shift><Alt>Tab" ];
      switch-group = [ "<Alt>Above_Tab" ];
      switch-group-backward = [ "<Shift><Alt>Above_Tab" ];
      switch-input-source = [ ];
      switch-input-source-backward = [ ];
      switch-panels = [ ];
      switch-panels-backward = [ ];
      switch-to-workspace-1 = [ ];
      switch-to-workspace-10 = [ ];
      switch-to-workspace-11 = [ ];
      switch-to-workspace-12 = [ ];
      switch-to-workspace-2 = [ ];
      switch-to-workspace-3 = [ ];
      switch-to-workspace-4 = [ ];
      switch-to-workspace-5 = [ ];
      switch-to-workspace-6 = [ ];
      switch-to-workspace-7 = [ ];
      switch-to-workspace-8 = [ ];
      switch-to-workspace-9 = [ ];
      switch-to-workspace-down = [ ];
      switch-to-workspace-last = [ ];
      switch-to-workspace-left = [ ];
      switch-to-workspace-right = [ ];
      switch-to-workspace-up = [ ];
      switch-windows = [ ];
      switch-windows-backward = [ ];
      toggle-above = [ ];
      toggle-fullscreen = [ "<Super>f" ];
      toggle-maximized = [ ];
      toggle-on-all-workspaces = [ ];
      toggle-shaded = [ ];
      unmaximize = [ ];
    };

    "org/gnome/desktop/wm/preferences" = {
      action-double-click-titlebar = "none";
      action-middle-click-titlebar = "none";
      action-right-click-titlebar = "none";
      button-layout = "appmenu:close";
      focus-mode = "sloppy";
      resize-with-right-button = true;
    };

    "org/gnome/mutter" = {
      workspaces-only-on-primary = true;
    };

    "org/gnome/mutter/wayland/keybindings" = {
      restore-shortcuts = [ ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      help = [ ];
      logout = [ ];
      magnifier = [ ];
      magnifier-zoom-in = [ ];
      magnifier-zoom-out = [ ];
      screensaver = [ ];
    };

    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = 900;
      sleep-inactive-ac-type = "nothing";
    };

    "org/gnome/shell/keybindings" = {
      focus-active-notification = [ ];
      open-application-menu = [ ];
      screenshot = [ "<Shift>Print" ];
      screenshot-window = [ "<Alt>Print" ];
      shift-overview-down = [ ];
      shift-overview-up = [ ];
      show-screen-recording-ui = [ "<Ctrl><Shift><Alt>R" ];
      show-screenshot-ui = [ "Print" ];
      switch-to-application-1 = [ ];
      switch-to-application-2 = [ ];
      switch-to-application-3 = [ ];
      switch-to-application-4 = [ ];
      switch-to-application-5 = [ ];
      switch-to-application-6 = [ ];
      switch-to-application-7 = [ ];
      switch-to-application-8 = [ ];
      switch-to-application-9 = [ ];
      toggle-application-view = [ ];
      toggle-message-tray = [ "<Super>c" ];
      toggle-overview = [ ];
      toggle-quick-settings = [ ];
    };

    "org/gnome/system/location" = {
      enabled = true;
      max-accuracy-level = "exact";
    };

    "org/gtk/gtk4/Settings/FileChooser" = {
      show-hidden = true;
      sort-directories-first = true;
    };

    "org/gtk/gtk4/settings/file-chooser" = {
      date-format = "regular";
      location-mode = "path-bar";
      show-hidden = true;
      show-size-column = true;
      show-type-column = true;
      sidebar-width = 140;
      sort-column = "name";
      sort-directories-first = true;
      sort-order = "ascending";
      type-format = "category";
      view-type = "list";
      window-size = mkTuple [ 1400 1000 ];
    };

    "org/gtk/settings/file-chooser" = {
      date-format = "regular";
      location-mode = "path-bar";
      show-hidden = true;
      show-size-column = true;
      show-type-column = true;
      sidebar-width = 140;
      sort-column = "name";
      sort-directories-first = true;
      sort-order = "ascending";
      type-format = "category";
      window-size = mkTuple [ 1400 1000 ];
    };
  };
}
