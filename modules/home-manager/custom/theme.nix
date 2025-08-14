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

    wayland.windowManager.hyprland.settings.exec-once =
      mkIf config.wayland.windowManager.hyprland.enable
        [
          "hyprctl setcursor ${config.stylix.cursor.name} ${toString config.stylix.cursor.size}"
        ];

    xdg.dataFile = lib.mkIf (config.stylix.image != null) (
      let
        magick = lib.getExe' pkgs.imagemagick "magick";
        wallpaperManipulations = pkgs.runCommandNoCC "wallpaperManipulations" { } ''
          mkdir -p $out

          ${magick} "${config.stylix.image}" -strip -resize 1000 -gravity center -extent 1000 -quality 90 "$out/wallpaper.thmb"
          ${magick} "${config.stylix.image}" -strip -thumbnail 500x500^ -gravity center -extent 500x500 "$out/wallpaper.sqre"
          ${magick} "${config.stylix.image}" -strip -scale 10% -blur 0x3 -resize 100% "$out/wallpaper.blur"
          ${magick} "$out/wallpaper.sqre" '(' -size 500x500 xc:white -fill "rgba(0,0,0,0.7)" -draw "polygon 400,500 500,500 500,0 450,0" -fill black -draw "polygon 500,500 500,0 450,500" ')' -alpha Off -compose CopyOpacity -composite "$out/wallpaper.quad"
        '';
      in
      {
        "wallpaper.thmb".source = "${wallpaperManipulations}/wallpaper.thmb";
        "wallpaper.sqre".source = "${wallpaperManipulations}/wallpaper.sqre";
        "wallpaper.blur".source = "${wallpaperManipulations}/wallpaper.blur";
        "wallpaper.quad".source = "${wallpaperManipulations}/wallpaper.quad";
      }
    );

    custom.uwsm.sliceAllocation.background = [ "xsettingsd" ];
    systemd.user.services.xsettingsd.Unit.After = [ "graphical-session.target" ];
  };
}
