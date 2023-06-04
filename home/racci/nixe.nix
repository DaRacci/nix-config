{ inputs, ... }:

let
  inherit (inputs.nix-colours) colourSchemes;
in {
  imports = [
    ./global
    ./global/features/desktop/gnome
    ./global/features/editor/code.nix
    ./global/features/games/osu.nix
    ./global/features/desktop/development
  ]; 
}
