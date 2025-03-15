{
  osConfig ? null,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom.theme;
in
{
  options.custom.theme = {
    enable = mkEnableOption "Theming" // {
      default =
        osConfig != null && hasAttr "stylix" osConfig && osConfig.stylix.enable && hasAttr "stylix" config;
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

    fonts.fontconfig = {
      defaultFonts = {
        sansSerif = [ config.stylix.fonts.sansSerif.name ];
        serif = [ config.stylix.fonts.serif.name ];
        monospace = [ config.stylix.fonts.monospace.name ];
        emoji = [ config.stylix.fonts.emoji.name ];
      };
    };

    # qt = {
    #   enable = true;
    #   platformTheme.name = "gtk3";
    #   style.name = "adwaita-qt6";
    # };

    wayland.windowManager.hyprland.settings.exec-once =
      mkIf config.wayland.windowManager.hyprland.enable
        [
          "hyprctl setcursor ${config.stylix.cursor.name} ${toString config.stylix.cursor.size}"
        ];

    custom.uwsm.sliceAllocation.background = [ "xsettingsd" ];
  };
}
