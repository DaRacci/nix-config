{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    home.packages = with pkgs.unstable; [
      (discord.overrideAttrs (oldAttrs: {
        desktopItem = (oldAttrs.desktopItem // {
          exec = oldAttrs.desktopItem.exec ++ "--enable-features=UseOzonePlatform --ozone-platform=wayland --enable-features=WaylandWindowDecorations";
        });
      }))
    ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}".directories = [
      ".config/discord"
    ];
  })
]
