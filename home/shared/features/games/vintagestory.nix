{ pkgs, ... }:
{
  home.packages = with pkgs; [ vintagestory ];

  user.persistence.directories = [ ".config/VintagestoryData/" ];
}
