{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    imports = [
      ./lutris.nix
      ./mangohud.nix
      ./minecraft.nix
      ./modding.nix
      ./osu.nix
      ./roblox.nix
      ./steam.nix
      ./vintagestory.nix
      ./vr.nix
      ./wine.nix
    ];

    home.packages = with pkgs.unstable; [ dualsensectl trigger-control ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}".directories = [ "Games" ];
  })
]
