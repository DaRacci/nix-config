{ pkgs, ... }:
{
  home.packages = with pkgs; [ bottles ];

  user.persistence.directories = [ ".local/share/bottles" ];
}
