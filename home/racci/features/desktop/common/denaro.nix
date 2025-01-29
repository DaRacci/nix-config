{ pkgs, ... }:
{
  home.packages = with pkgs; [ denaro ];

  user.persistence.directories = [ ".config/Nickvision/Nickvision Denaro" ];
}
