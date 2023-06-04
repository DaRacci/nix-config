{ pkgs, ...}: {
  imports = [ ../common ];

  home.packages = with pkgs; [
    glib
    gnome-extension-manager
    gnomeExtensions.vitals
    gnomeExtensions.utcclock
    gnomeExtensions.username-and-hostname-to-panel
    gnomeExtensions.useless-gaps
    gnomeExtensions.tray-icons-reloaded
  ];

  dconf.settings = {
    "org.gnome.desktop.datetime" = {
      automatic-timezone = true;
    };

    "org.gnome.desktop.interface" = {
      clock-format = "24h";
      clock-show-date = true;
      clock-show-seconds = true;
      clock-show-weekday = true;
      enable-hot-corners = false;
      gtk-enable-primary-paste = false;
    };

    "org.gnome.desktop.peripherals.mouse" = {
      accel-profile = "flat";
    };

    "org.gnome.shell.weather" = {
      #? TODO
    };
    
    "org.gnome.shell.world-clocks" = {
      #? TODO
    };

    "org.gnome.system.location" = {
      enabled = true;
      max-accuracy-level = "exact";
    };

    "org.gtk.gtk4.Settings.FileChooser" = {
      show-hidden = true;
      sort-directories-first = true;
    };

    "org.gnome.shell.keybindings" = {
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
      toggle-overview = [];
    };

    "org.gnome.settings-daemon.plugins.power" = {
      sleep-inactive-ac-timeout = 900;
      sleep-inactive-ac-type = "nothing";
    };
    
    "org.gnome.settings-daemon.plugins.media-keys" = {
      help = [];
      logout = [];
      magnifier = [];
      magnifier-zoom-in = [];
      magnifier-zoom-out = [];
      screensaver = [];
    };

    "org.gnome.desktop.wm.keybindings" = {
      switch-input-source = [];
      switch-input-source-backward = [];
      switch-panels = [];
      switch-panels-backward = [];
      switch-to-workspace-1 = [];
      switch-to-workspace-last = [];
      switch-to-workspace-down = [];
      switch-to-workspace-up = [];
      move-to-workspace-up = [];
      move-to-workspace-down = [];
      move-to-workspace-1 = [];
      move-to-workspace-left = [];
      begin-move = [];
      begin-resize = [];
      cycle-group = [];
      cycle-group-backward = [];
      cycle-panels = [];
      cycle-panels-backward = [];
      cycle-windows = [];
      cycle-windows-backward = [];
    };

    "org.gnome.desktop.wm.preferences" = {
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
    ];
  };

  home.file.".config/monitors.xml".text = ''
<monitors version="2">
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
