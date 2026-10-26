{ pkgs, ... }:
let
  inherit (pkgs) vintagestory;
in
{
  home.packages = [ vintagestory ];

  user.persistence.directories = [ ".config/VintagestoryData/" ];
}
