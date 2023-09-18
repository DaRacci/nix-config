{ pkgs, persistenceDirectory, ... }: {
  imports = [
    ./lutris.nix
    ./mangohud.nix
    ./minecraft.nix
    ./modding.nix
    ./osu.nix
    ./roblox.nix
    ./steam.nix
    ./vintagestory.nix
    ./wine.nix
  ];

  home.packages = with pkgs.unstable; [ dualsensectl trigger-control ];
  home.persistence."${persistenceDirectory}".directories = [ "Games" ];
}
