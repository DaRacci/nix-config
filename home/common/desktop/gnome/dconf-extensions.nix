{ config, pkgs, lib, ... }: {
  home.packages = with pkgs.gnomeExtensions; [
    # Quick Access and Panel
    quick-settings-audio-devices-hider
    quick-settings-audio-panel
    home-assistant-extension
    clipboard-indicator
    tailscale-qs
    appindicator
    open-bar
    vitals

    # Misc Improvements
    wallpaper-slideshow
    quick-text
    trimmer

    # Search and Launch
    fuzzy-app-search
    quick-web-search

    # Theme and appearance
    gnome-40-ui-improvements
    just-perfection
    blur-my-shell
  ];

  dconf.settings = with lib.hm.gvariant; {
    "org/gnome/shell" = {
      enabled-extensions = [
        "apps-menu@gnome-shell-extensions.gcampax.github.com"
        "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
        "clipboard-indicator@tudmotu.com"
        "Vitals@CoreCoding.com"
        "blur-my-shell@aunetx"
        "appindicatorsupport@rgcjonas.gmail.com"
        "gnome-fuzzy-app-search@gnome-shell-exstions.Czarlie.gitlab.com"
        "tailscale@joaophi.github.com"
        "quicktext@brainstormtrooper.github.io"
        "quicksettings-audio-devices-hider@marcinjahn.com"
        "just-perfection-desktop@just-perfection"
        "azwallpaper@azwallpaper.gitlab.com"
        "openbar@neuromorph"
        "gnome-ui-tune@itstime.tech"
        "hass-gshell@geoph9-on-github"
      ];
    };

    "org/gnome/shell/extensions/azwallpaper" = {
      slideshow-directory = "/home/${config.home.username}/Pictures/Wallpapers";
    };

    "org/gnome/shell/extensions/clipboard-indicator" = {
      clear-history = [ ];
      history-size = 1000;
      move-item-first = true;
      next-entry = [ ];
      prev-entry = [ ];
      private-mode-binding = [ ];
      strip-text = false;
      toggle-menu = [ "<Super>v" ];
    };

    "org/gnome/shell/extensions/gnome-ui-tune" = {
      increase-thumbnails-size = "200%";
      slideshow-slide-duration = mkTuple [ 1 0 0 ];
    };

    "org/gnome/shell/extensions/just-perfection" = {
      search = false;
      dash = false;
      switcher-popup-delay = false;
      window-demands-attention-focus = true;
      workspace-wrap-around = true;
      activities-button = false;
    };

    "org/gnome/shell/extensions/openbar" = {
      balpha = 1.0;
      bartype = "Islands";
      bgalpha = 0.0;
      bgalpha2 = 0.7;
      bgpalette = false;
      bcolor = [ "0.7960784435272217" "0.2078431248664856" "0.23921562731266022" ];
      bradius = 30.0;
      bwidth = 3.0;
      default-font = "Sans 12";
      fgalpha = 1.0;
      font = "Source Sans 3 Ultra-Light 16";
      gradient = false;
      halpha = 0.7;
      heffect = false;
      height = 40;
      hpad = 0.0;
      margin = 0.0;
      neon = false;
      overview = true;
      shadow = false;
    };

    "org/gnome/shell/extensions/quicksettings-audio-devices-hider" = {
      excluded-input-names = [ "Digital Input (S/PDIF) – HD Pro Webcam C920" "Microphone – HD Pro Webcam C920" "Analog Input – Scarlett Solo USB" ];
      excluded-output-names = [ "HDMI / DisplayPort 3 – GA102 High Definition Audio Controller" "HDMI / DisplayPort 2 – GA102 High Definition Audio Controller" "HDMI / DisplayPort – GA102 High Definition Audio Controller" "Digital Output (S/PDIF) – Scarlett Solo USB" "Analog Output – Scarlett Solo USB" ];
    };

    "org/gnome/shell/extensions/quicktext" = {
      quick-filepath = "/home/${config.home.username}/Documents/obsidian/Notes.md";
      quick-hideacted = true;
      quick-multiline = false;
      quick-prepend = "";
    };

    "org/gnome/shell/extensions/vitals" = {
      update-time = 1;
      network-speed-format = 1;
      fixed-widths = false;
      hide-zeros = true;
      menu-centered = true;
      show-fan = false;
      show-system = false;
      show-storage = false;
      show-voltage = false;
      hot-sensors = [ "_temperature_asusec_t_sensor_" "_temperature_asusec_cpu_" "_processor_usage_" "_processor_frequency_" "_memory_usage_" "__network-rx_max__" "__network-tx_max__" ];
    };

    "org/gnome/shell/extensions/hass-data" = {
      default-panel-icon = "/icons/hass-symbolic.svg";
      hass-url = "https://homeassistant.racci.dev";
      sensors-refresh = true;
      sensors-refresh-seconds = "5";
      show-notifications = true;
    };
  };
}
