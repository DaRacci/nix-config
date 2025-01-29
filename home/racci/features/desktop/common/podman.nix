{ pkgs, ... }:
{
  home.packages = with pkgs; [ pods ];

  user.persistence.directories = [ ".config/pods" ];
}
