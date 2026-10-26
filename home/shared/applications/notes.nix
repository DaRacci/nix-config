{ pkgs, ... }:
let
  inherit (pkgs) obsidian;
in
{
  home.packages = [ obsidian ];

  user.persistence.directories = [ ".config/obsidian" ];
}
