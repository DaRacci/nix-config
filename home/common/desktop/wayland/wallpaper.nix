{ pkgs, ... }:
let
  script = pkgs.writeShellScriptBin "sww-random-wallpaper" ''
    export SWWW_TRANSITION=random
    export SWWW_TRANSITION_STEP=2
    export SWWW_TRANSITION_DURATION=4
    export SWWW_TRANSITION_FPS=165
    export SWWW_TRANSITION_ANGLE=90
    export SWWW_TRANSITION_POS=left
    export SWWW_TRANSITION_BEZIER=.07,.56,1,.25

    # This controls (in seconds) when to switch to the next image
    INTERVAL=10
    DIRECTORY=$HOME/Pictures/Wallpapers

    while true; do
      find "$1" | while read -r img; do
        echo "$((RANDOM % 1000)):$img"
      done | sort -n | cut -d':' -f2- | while read -r img; do
        ${pkgs.swww} img "$img"
        sleep $INTERVAL
      done
    done
  '';
in
{
  home.packages = with pkgs; [
    swww
  ];
}
