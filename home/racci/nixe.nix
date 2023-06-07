{ inputs, pkgs, ... }:

let
  inherit (inputs.nix-colours) colourSchemes;
in {
  imports = [
    ./global
    ./global/features/desktop/gnome
    ./global/features/desktop/editor/code.nix
    ./global/features/desktop/games/osu.nix
    ./global/features/desktop/games/steam.nix
    ./global/features/desktop/games/satisfactory.nix
    ./global/features/desktop/development
  ];
}
