{ pkgs, ... }:
{
  home.packages = with pkgs; [ vesktop ];

  user.persistence.directories = [ ".config/vesktop" ];
}
