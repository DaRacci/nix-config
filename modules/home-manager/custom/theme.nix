{ osConfig, config, pkgs, lib, ... }: with lib; let
  cfg = config.custom.theme;
in
{
  options.custom.theme = {
    enable = mkEnableOption "Theming" // {
      default = hasAttr "stylix" osConfig
        && osConfig.stylix.enable
        && hasAttr "stylix" config;
    };
  };

  config = mkIf cfg.enable rec {
    gtk = {
      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
    };

    services.xsettingsd = {
      enable = true;
      settings = {
        "Net/IconThemeName" = "${gtk.iconTheme.name}";
      };
    };

    # qt = {
    #   enable = true;
    #   platformTheme.name = "gtk3";
    #   style.name = "adwaita-qt6";
    # };

    wayland.windowManager.hyprland.settings.exec-once = mkIf config.wayland.windowManager.hyprland.enable [
      "hyprctl setcursor ${config.stylix.cursor.name} ${toString config.stylix.cursor.size}"
    ];
  };
}
