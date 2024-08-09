_:
# let
# randomWallpaperScript = pkgs.writeShellApplication {
#   name = "sww-random-wallpaper";
#   runtimeInputs = [ pkgs.unstable.swww ];
#   text = ''
#     export SWWW_TRANSITION=random
#     export SWWW_TRANSITION_STEP=2
#     export SWWW_TRANSITION_DURATION=2
#     export SWWW_TRANSITION_FPS=165
#     export SWWW_TRANSITION_ANGLE=90
#     export SWWW_TRANSITION_POS=left
#     export SWWW_TRANSITION_BEZIER=.07,.56,1,.25

#     # This controls (in seconds) when to switch to the next image
#     INTERVAL=30
#     DIRECTORY=$HOME/Pictures/Wallpapers

#     FREEZE_FILE=$HOME/.cache/sww-random-wallpaper-freeze

#     while true; do
#       if [ -f "$FREEZE_FILE" ]; then
#         sleep $INTERVAL
#         continue
#       fi

#       find "$DIRECTORY" -type f | while read -r img; do
#         echo "$((RANDOM % 1000)):$img"
#       done | sort -n | cut -d':' -f2- | while read -r img; do
#         swww img "$img"
#         sleep $INTERVAL
#       done
#     done
#   '';
# };
# in
{
  wayland.windowManager.hyprland.settings.exec-once = [
    # "sleep 1 && ${pkgs.unstable.swww}/bin/swww-daemon"
    # "sleep 1 && ${randomWallpaperScript}/bin/sww-random-wallpaper"
  ];
}
