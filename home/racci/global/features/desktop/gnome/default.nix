{ pkgs, ...}: {
  imports = [ ../common ];

  home.packages = with pkgs; [
    glib
    curtail
    gnome-decoder
    eyedropper
    raider
    junction
  ] ++ (with pkgs.gnomeExtensions; [
    vitals
    gsconnect
    lock-keys
    clipboard-indicator
    pop-shell
    blur-my-shell
    tactile
  ]);

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = 1;
  };

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "apps-menu@gnome-shell-extensions.gcampax.github.com"
        "clipboard-indicator@tudmotu.com"
        "gsconnect@andyholmes.github.io"
        "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
        "lockkeys@vaina.lt"
        "pop-shell@system76.com"
        "Vitals@CoreCoding.com"
      ];
    };

    "org/gnome/desktop/datetime" = {
      automatic-timezone = true;
    };

    "org/gnome/desktop/interface" = {
      clock-format = "24h";
      clock-show-date = true;
      clock-show-seconds = true;
      clock-show-weekday = true;
      enable-hot-corners = false;
      gtk-enable-primary-paste = false;
    };

    "org/gnome/desktop/peripherals/mouse" = {
      accel-profile = "flat";
    };

    "org/gnome/shell/weather" = {
      #? TODO
    };
    
    "org/gnome/shell/world-clocks" = {
      #? TODO
    };

    "org/gnome/system/location" = {
      enabled = true;
      max-accuracy-level = "exact";
    };

    "org/gtk/gtk4/Settings/FileChooser" = {
      show-hidden = true;
      sort-directories-first = true;
    };

    "org/gnome/shell/keybindings" = {
      focus-active-notification = [];
      open-application-menu = [];
      screenshot = ["<Shift>Print"];
      screenshot-window = ["<Alt>Print"];
      shift-overview-down = [];
      shift-overview-up = [];
      show-screen-recording-ui = ["<Ctrl><Shift><Alt>R"];
      show-screenshot-ui = ["Print"];
      switch-to-application-1 = [];
      switch-to-application-2 = [];
      switch-to-application-3 = [];
      switch-to-application-4 = [];
      switch-to-application-5 = [];
      switch-to-application-6 = [];
      switch-to-application-7 = [];
      switch-to-application-8 = [];
      switch-to-application-9 = [];
      toggle-application-view = [];
      toggle-message-tray = ["<Super>v"];
      toggle-overview = [];
    };

    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = 900;
      sleep-inactive-ac-type = "nothing";
    };
    
    "org/gnome/settings-daemon/plugins/media-keys" = {
      help = [];
      logout = [];
      magnifier = [];
      magnifier-zoom-in = [];
      magnifier-zoom-out = [];
      screensaver = [];
    };

    "org/gnome/desktop/wm/keybindings" = {
      active-window-menu = [];
      always-on-top = [];
      begin-move = [];
      begin-resize = [];
      close = ["<Super>q"];
      cycle-group = [];
      cycle-group-backward = [];
      cycle-panels = [];
      cycle-panels-backward = [];
      cycle-windows = [];
      cycle-windows-backward = [];
      lower = [];
      maximize = [];
      maximize-horizontally = [];
      maximize-vertically = [];
      minimize = [];
      move-to-center = [];
      move-to-corner-ne = [];
      move-to-corner-nw = [];
      move-to-corner-se = [];
      move-to-corner-sw = [];
      move-to-monitor-down = [];
      move-to-monitor-left = [];
      move-to-monitor-right = [];
      move-to-monitor-up = [];
      move-to-side-e = [];
      move-to-side-n = [];
      move-to-side-s = [];
      move-to-side-w = [];
      move-to-workspace-1 = [];
      move-to-workspace-2 = [];
      move-to-workspace-3 = [];
      move-to-workspace-4 = [];
      move-to-workspace-5 = [];
      move-to-workspace-6 = [];
      move-to-workspace-7 = [];
      move-to-workspace-8 = [];
      move-to-workspace-9 = [];
      move-to-workspace-10 = [];
      move-to-workspace-11 = [];
      move-to-workspace-12 = [];
      move-to-workspace-down = [];
      move-to-workspace-last = [];
      move-to-workspace-left = [];
      move-to-workspace-right = [];
      panel-main-menu = [];
      panel-run-dialog = ["<Alt>F2"];
      raise = [];
      raise-or-lower = [];
      set-spew-mark = [];
      show-desktop = [];
      switch-applications = ["<Alt>Tab"];
      switch-applications-backward = ["<Shift><Alt>Tab"];
      switch-group = ["<Alt>Above_Tab"];
      switch-group-backward = ["<Shift><Alt>Above_Tab"];
      switch-input-source = [];
      switch-input-source-backward = [];
      switch-panels = [];
      switch-panels-backward = [];
      switch-to-workspace-1 = [];
      switch-to-workspace-2 = [];
      switch-to-workspace-3 = [];
      switch-to-workspace-4 = [];
      switch-to-workspace-5 = [];
      switch-to-workspace-6 = [];
      switch-to-workspace-7 = [];
      switch-to-workspace-8 = [];
      switch-to-workspace-9 = [];
      switch-to-workspace-10 = [];
      switch-to-workspace-11 = [];
      switch-to-workspace-12 = [];
      switch-to-workspace-down = [];
      switch-to-workspace-last = [];
      switch-to-workspace-left = [];
      switch-to-workspace-right = [];
      switch-to-workspace-up = [];
      switch-windows = [];
      switch-windows-backward = [];
      toggle-above = [];
      toggle-fullscreen = ["<Super>f"];
      toggle-maximized = [];
      toggle-on-all-workspaces = [];
      toggle-shaded = [];
      unmaximize = [];
    };

    "org/gnome/desktop/wm/preferences" = {
      action-double-click-titlebar = "none";
      action-middle-click-titlebar = "none";
      action-right-click-titlebar = "none";
      button-layout = "appmenu:close";
      resize-with-right-button = true;
      focus-mode = "sloppy";
    };
  };

  home.persistence."/persist/home/racci" = {
    directories = [
      ".config/evolution"
      ".config/geary"
      ".config/goa-1.0"
      ".local/share/geary" #? Whats stored here?
      ".local/share/gnome-control-center-goa-helper" # ? Whats stored here?
      ".local/share/Trash" #? Do i really need this?
      # Gnome Extensions and settings
      ".cache/clipboard-indicator@tudmotu.com" # Clipboard history
      ".config/gsconnect"                      # Gsconnect
    ];
  };

  xdg.mimeApps.associations.added = [
    "x-scheme-handler/sms" = [ "org.gnome.Shell.Extensions.GSConnect.desktop" ];
    "x-scheme-handler/tel" = [ "org.gnome.Shell.Extensions.GSConnect.desktop" ];
  ];

  home.file.".config/monitors.xml".text = ''
<monitors version="2">
  <configuration>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <monitor>
        <monitorspec>
          <connector>DP-0</connector>
          <vendor>AOC</vendor>
          <product>AG271QG4</product>
          <serial>0x00000010</serial>
        </monitorspec>
        <mode>
          <width>2560</width>
          <height>1440</height>
          <rate>143.912</rate>
        </mode>
      </monitor>
    </logicalmonitor>
    <logicalmonitor>
      <x>2560</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <monitor>
        <monitorspec>
          <connector>DP-2</connector>
          <vendor>AUS</vendor>
          <product>ROG PG27V</product>
          <serial>#ASNtjK9gdB7d</serial>
        </monitorspec>
        <mode>
          <width>2560</width>
          <height>1440</height>
          <rate>165.000</rate>
        </mode>
      </monitor>
    </logicalmonitor>
    <logicalmonitor>
      <x>5120</x>
      <y>0</y>
      <scale>1</scale>
      <monitor>
        <monitorspec>
          <connector>DP-4</connector>
          <vendor>AOC</vendor>
          <product>AG271QG4</product>
          <serial>0x000000aa</serial>
        </monitorspec>
        <mode>
          <width>2560</width>
          <height>1440</height>
          <rate>143.912</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
  <configuration>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <monitor>
        <monitorspec>
          <connector>DP-1</connector>
          <vendor>AOC</vendor>
          <product>AG271QG4</product>
          <serial>0x00000010</serial>
        </monitorspec>
        <mode>
          <width>2560</width>
          <height>1440</height>
          <rate>143.912</rate>
        </mode>
      </monitor>
    </logicalmonitor>
    <logicalmonitor>
      <x>5120</x>
      <y>0</y>
      <scale>1</scale>
      <monitor>
        <monitorspec>
          <connector>DP-3</connector>
          <vendor>AOC</vendor>
          <product>AG271QG4</product>
          <serial>0x000000aa</serial>
        </monitorspec>
        <mode>
          <width>2560</width>
          <height>1440</height>
          <rate>143.912</rate>
        </mode>
      </monitor>
    </logicalmonitor>
    <logicalmonitor>
      <x>2560</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <monitor>
        <monitorspec>
          <connector>DP-2</connector>
          <vendor>AUS</vendor>
          <product>ROG PG27V</product>
          <serial>#ASNtjK9gdB7d</serial>
        </monitorspec>
        <mode>
          <width>2560</width>
          <height>1440</height>
          <rate>165.000</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
  '';
}
