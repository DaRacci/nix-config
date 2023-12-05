{ pkgs, lib, ... }: {
  imports = [ ../common ];

  home.packages = with pkgs; [
    glib
    curtail
    gnome-decoder
    eyedropper
    raider
  ] ++ (with pkgs.gnomeExtensions; [
    vitals
    clipboard-indicator
    pop-shell
    blur-my-shell
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
        "pop-shell@system76.com"
        "Vitals@CoreCoding.com"
        "blur-my-shell@aunetx"
      ];
    };

    "org/gnome/shell/extensions/clipboard-indicator" = {
      strip-text = true;
      history-size = 1000;
      move-item-first = true;
    };

    "org/gnome/shell/extensions/pop-shell" = {
      fullscreen-launcher = true;
      smart-gaps = true;
      snap-to-grid = true;
    };

    "org/gnome/shell/extensions/vitals" = {
      update-time = 1;
      network-speed-format = 1;
      fixed-width = false;
      hide-zeros = true;
      show-fan = false;
      show-system = false;
      show-storage = false;
      show-voltage = false;
      hot-sensors = [ "_temperature_asusec_t_sensor_" "_temperature_asusec_cpu_" "_processor_usage_" "_processor_frequency_" "_memory_usage_" "__network-rx_max__" "__network-tx_max__" ];
    };

    # TODO
    "org/gnome/desktop/background" = {
      # picture-uri = "" # File Uri, Select random from backgrounds folder
      primary-color = "#023c88";
      secondary-color = "#5789ca";
    };

    "org/gnome/desktop/datetime" = {
      automatic-timezone = true;
    };

    "org/gnome/desktop/interface" = {
      clock-format = "24h";
      clock-show-date = true;
      clock-show-seconds = true;
      clock-show-weekday = true;
      color-scheme = "prefer-dark";
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
      toggle-message-tray = [ "<Super>v" ];
      toggle-overview = [ ];
    };

    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = 900;
      sleep-inactive-ac-type = "nothing";
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      help = [ ];
      logout = [ ];
      magnifier = [ ];
      magnifier-zoom-in = [ ];
      magnifier-zoom-out = [ ];
      screensaver = [ ];
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
      move-to-workspace-2 = [ ];
      move-to-workspace-3 = [ ];
      move-to-workspace-4 = [ ];
      move-to-workspace-5 = [ ];
      move-to-workspace-6 = [ ];
      move-to-workspace-7 = [ ];
      move-to-workspace-8 = [ ];
      move-to-workspace-9 = [ ];
      move-to-workspace-10 = [ ];
      move-to-workspace-11 = [ ];
      move-to-workspace-12 = [ ];
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
      switch-to-workspace-2 = [ ];
      switch-to-workspace-3 = [ ];
      switch-to-workspace-4 = [ ];
      switch-to-workspace-5 = [ ];
      switch-to-workspace-6 = [ ];
      switch-to-workspace-7 = [ ];
      switch-to-workspace-8 = [ ];
      switch-to-workspace-9 = [ ];
      switch-to-workspace-10 = [ ];
      switch-to-workspace-11 = [ ];
      switch-to-workspace-12 = [ ];
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
      resize-with-right-button = true;
      focus-mode = "sloppy";
    };
  };

  xdg.mimeApps.associations.added = {
    "x-scheme-handler/sms" = [ "org.gnome.Shell.Extensions.GSConnect.desktop;" ];
    "x-scheme-handler/tel" = [ "org.gnome.Shell.Extensions.GSConnect.desktop;" ];
  };

  # home.file.".config/monitors.xml".text =
  #   let
  #     mkMonitor = connector: { monitorspec, mode, position }: {

  #     };

  #     monitors = pkgs.xorg.xrandr.getMonitors;


  #   in
  #   ''
  #     <monitors version="2">
  #       <configuration>
  #         <logicalmonitor>
  #           <x>0</x>
  #           <y>1257</y>
  #           <scale>1</scale>
  #           <monitor>
  #             <monitorspec>
  #               <connector>HDMI-3</connector>
  #               <vendor>AOC</vendor>
  #               <product>27G1G4</product>
  #               <serial>0x0002071c</serial>
  #             </monitorspec>
  #             <mode>
  #               <width>1920</width>
  #               <height>1080</height>
  #               <rate>119.982</rate>
  #             </mode>
  #           </monitor>
  #         </logicalmonitor>
  #         <logicalmonitor>
  #           <x>2189</x>
  #           <y>0</y>
  #           <scale>1</scale>
  #           <monitor>
  #             <monitorspec>
  #               <connector>HDMI-2</connector>
  #               <vendor>GSM</vendor>
  #               <product>LG FULL HD</product>
  #               <serial>0x01010101</serial>
  #             </monitorspec>
  #             <mode>
  #               <width>1920</width>
  #               <height>1080</height>
  #               <rate>74.973</rate>
  #             </mode>
  #           </monitor>
  #         </logicalmonitor>
  #         <logicalmonitor>
  #           <x>1920</x>
  #           <y>1080</y>
  #           <scale>1</scale>
  #           <primary>yes</primary>
  #           <monitor>
  #             <monitorspec>
  #               <product>Odyssey G50A</product>
  #               <serial>H4ZRB04080</serial>
  #             </monitorspec>
  #             <mode>
  #               <width>2560</width>
  #               <height>1440</height>
  #               <rate>164.999</rate>
  #             </mode>
  #           </monitor>
  #         </logicalmonitor>
  #       </configuration>
  #       <configuration>
  #         <logicalmonitor>
  #           <x>0</x>
  #           <y>191</y>
  #           <scale>1</scale>
  #           <monitor>
  #             <monitorspec>
  #               <connector>HDMI-3</connector>
  #               <vendor>GSM</vendor>
  #               <product>LG FULL HD</product>
  #               <serial>0x01010101</serial>
  #             </monitorspec>
  #             <mode>
  #               <width>1920</width>
  #               <height>1080</height>
  #               <rate>74.973</rate>
  #             </mode>
  #           </monitor>
  #         </logicalmonitor>
  #         <logicalmonitor>
  #           <x>1920</x>
  #           <y>0</y>
  #           <scale>1</scale>
  #           <primary>yes</primary>
  #           <monitor>
  #             <monitorspec>
  #               <connector>DP-3</connector>
  #               <vendor>SAM</vendor>
  #               <product>Odyssey G50A</product>
  #               <serial>H4ZRB04080</serial>
  #             </monitorspec>
  #             <mode>
  #               <width>2560</width>
  #               <height>1440</height>
  #               <rate>164.999</rate>
  #             </mode>
  #           </monitor>
  #         </logicalmonitor>
  #       </configuration>
  #     </monitors>
  #   '';

  user.persistence.directories = [
    ".config/evolution"
    ".config/geary"
    ".config/goa-1.0"
    ".local/share/geary" #? Whats stored here?
    ".local/share/gnome-control-center-goa-helper" # ? Whats stored here?
    ".local/share/Trash" #? Do i really need this?
    # Gnome Extensions and settings
    ".cache/clipboard-indicator@tudmotu.com" # Clipboard history
    ".config/gsconnect" # Gsconnect
  ];
}
