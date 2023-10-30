{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  home.packages = with pkgs; [
    (discord.overrideAttrs (oldAttrs: {
      desktopItem = (oldAttrs.desktopItem // {
        exec = oldAttrs.desktopItem.exec ++ "--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-features=WaylandWindowDecorations";
      });
    }))
  ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".config/discord"
  ];
}
