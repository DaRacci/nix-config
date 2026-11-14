{ pkgs, ... }:
let
  inherit (pkgs) vintagestory;
in
{
  home.packages = [ vintagestory ];

  user.files.persistence.directories = [ ".config/VintagestoryData/" ];
}
