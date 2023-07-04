{ inputs, pkgs, ... }:

let
  inherit (inputs.nix-colours) colourSchemes;
in {
  imports = [
    ./global

    ./global/features/desktop/gnome
    ./global/features/desktop/hyprland

    ./global/features/desktop/games
    ./global/features/desktop/development
  ];
}
