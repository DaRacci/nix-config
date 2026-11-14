{ pkgs, ... }:
let
  inherit (pkgs) bottles;
in
{
  home.packages = [ bottles ];

  user.files.persistence.directories = [
    ".local/share/bottles"
    ".local/share/umu"
  ];
}
