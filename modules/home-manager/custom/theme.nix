{ config, pkgs, lib, ... }: with lib; let cfg = config.custom.theme; in {
  options.custom.theme = {
    enable = mkEnableOption "Theming" // { default = true; };

    cursor = {
      name = mkOption {
        type = types.str;
        default = null;
      };

      size = mkOption {
        type = types.int;
        default = 32;
      };

      package = mkOption {
        type = types.package;
        default = null;
      };
    };
  };

  config = mkIf cfg.enable rec {
    home.packages = with pkgs; [
      twemoji-color-font
      noto-fonts-emoji
    ];

    gtk = {
      enable = true;

      theme = {
        name = "Adwaita-dark";
        package = null;
      };

      iconTheme = {
        name = "Adwaita";
        package = pkgs.gnome.adwaita-icon-theme;
      };

      cursorTheme = mkIf (cfg.cursor.package != null) {
        inherit (cfg.cursor) name size package;
      };
    };

    services.xsettingsd = {
      enable = true;
      settings = {
        "Net/ThemeName" = "${gtk.theme.name}";
        "Net/IconThemeName" = "${gtk.iconTheme.name}";
      };
    };

    home.pointerCursor = mkIf (cfg.cursor.package != null) {
      inherit (cfg.cursor) name size package;
    };

    qt = {
      enable = true;
      platformTheme = "gtk3";
      style.name = "adwaita-qt6";
    };

    wayland.windowManager.hyprland.settings.exec-once = mkIf config.wayland.windowManager.hyprland.enable [
      "hyprctl setcursor ${cfg.cusor.name} ${cfg.cursor.size}"
    ];
  };
}