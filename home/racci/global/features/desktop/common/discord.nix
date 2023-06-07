{ pkgs, ... }: {

  home.packages = with pkgs; [
    (discord.overrideAttrs (oldAttrs: {
      desktopItem = (oldAttrs.desktopItem // {
        exec = oldAttrs.desktopItem.exec ++ "--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-features=WaylandWindowDecorations";
      });
    }))
  ];

  home.persistence = {
    "/persist/home/racci".directories = [ ".config/discord" ];
  };
}
