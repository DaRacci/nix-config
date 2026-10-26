{ pkgs, ... }:
let
  inherit (pkgs) bottles;
in
{
  home.packages = [ bottles ];

  user.persistence.directories = [
    ".local/share/bottles"
    ".local/share/umu"
  ];
}
