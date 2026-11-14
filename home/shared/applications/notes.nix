{ pkgs, ... }:
let
  inherit (pkgs) obsidian;
in
{
  home.packages = [ obsidian ];

  user.files.persistence.directories = [ ".config/obsidian" ];
}
