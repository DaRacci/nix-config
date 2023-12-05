{ pkgs, ... }: {
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

  user.persistence.directories = [ "Games" ];
}

