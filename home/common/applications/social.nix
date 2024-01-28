{ pkgs, ... }: {
  home.packages = with pkgs.unstable; [
    (discord.overrideAttrs (oldAttrs: {
      desktopItem = (oldAttrs.desktopItem // {
        exec = oldAttrs.desktopItem.exec ++ "--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-features=WaylandWindowDecorations";
      });
    }))
  ];

  user.persistence.directories = [
    ".config/discord"
  ];
}
