#!/usr/bin/env bash

if [ $# -ne 1 ] || { [ "$1" != "area" ] && [ "$1" != "output" ]; }; then
  echo "Usage: screenshot <area|output>"
  exit 1
fi

capture=$1
pictures_dir="${SCREENSHOT_PICTURES_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"
year_month="${SCREENSHOT_YEAR_MONTH:-$(date '+%Y/%m')}"
timestamp="${SCREENSHOT_TIMESTAMP:-$(date '+%Y%m%d_%H%M%S')}"
dated_folder="${pictures_dir}/Screenshots/${year_month}"
save_path="${dated_folder}/Screenshot_${timestamp}.png"
save_path_annotated="${dated_folder}/Screenshot_${timestamp}_annotated.png"

mkdir -p "$dated_folder"

GRIMBLAST_HIDE_CURSOR=1 grimblast --freeze copysave "$capture" "$save_path"
paplay "$SCREENSHOT_SHUTTER_SOUND"

action=$(notify-send \
  "Screenshot Captured" \
  "Screenshot saved at $save_path" \
  --app-name="hyprland" \
  --category="action" \
  --icon="$save_path" \
  --app-name="Screenshot" \
  --action=Open \
  --action=Edit)

if [ "$action" = "0" ]; then
  xdg-open "$save_path"
elif [ "$action" = "1" ]; then
  satty --filename "$save_path" --fullscreen --output-filename "$save_path_annotated"
fi
