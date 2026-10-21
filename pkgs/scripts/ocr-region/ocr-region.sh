#!/usr/bin/env bash

TEMP_FILE="$(mktemp --suffix=.png)"
PROCESSED_FILE="$(mktemp --suffix=.png)"
BINARIZED_FILE="$(mktemp --suffix=.png)"
trap 'rm -f "$TEMP_FILE" "$PROCESSED_FILE" "$BINARIZED_FILE"' EXIT

GRIMBLAST_HIDE_CURSOR=1 grimblast --freeze save area "$TEMP_FILE"

# upscale 3x, greyscale, sharpen, normalise contrast, adds 10px border, and deskew.
# This significantly improves recognition on small or low-DPI captures.
convert "$TEMP_FILE" \
  -resize 300% \
  -colorspace Gray \
  -deskew 40% \
  -sharpen 0x1 \
  -contrast-stretch 0.15%x0.15% \
  -bordercolor White \
  -border 10x10 \
  "$PROCESSED_FILE"
IMAGE_DIMS=$(identify -format "%wx%h" "$PROCESSED_FILE" 2>&1 || echo "unknown")

trim_whitespace() {
  printf "%s" "$1" | tr -d '[:space:]'
}

try_ocr() {
  local psm="$1"
  local image_file="$2"
  local result
  local stderr_file;
  stderr_file=$(mktemp);

  result=$(TESSDATA_PREFIX="${OCR_REGION_TESSDATA_PREFIX}" tesseract \
    --oem 1 \
    --psm "$psm" \
    "$image_file" - -l eng jpn osd 2>"$stderr_file")
  trim_whitespace "$result"
  cat "$stderr_file" >&9;
  rm -f "$stderr_file";
}

OCR_TEXT=""
DETECTION_METHOD=""
STDERR_FILE=$(mktemp);
exec 9>"$STDERR_FILE";
for psm in 1 3 6; do
  OCR_TEXT=$(try_ocr "$psm" "$PROCESSED_FILE")
  if [ -n "$OCR_TEXT" ]; then
    DETECTION_METHOD="PSM $psm (normal)"
    break
  fi

  if [ ! -f "$BINARIZED_FILE" ] || [ "$psm" -eq 1 ]; then
    if [ ! -f "$BINARIZED_FILE" ]; then
      convert "$PROCESSED_FILE" -threshold 40% "$BINARIZED_FILE"
    fi
  fi

  OCR_TEXT=$(try_ocr "$psm" "$BINARIZED_FILE")
  if [ -n "$OCR_TEXT" ]; then
    DETECTION_METHOD="PSM $psm (binarized)"
    break
  fi
done
exec 9>&-;
STDERR_LOG=$(cat "$STDERR_FILE" 2>/dev/null);
rm -f "$STDERR_FILE";

if [ -z "$OCR_TEXT" ]; then
  notify-send \
    "OCR: No Text Detected" \
    "Image: ''${IMAGE_DIMS}px - Errors: $STDERR_LOG" \
    --app-name="hyprland" \
    --category="action" \
    --icon="dialog-warning" \
    --urgency="normal"
else
  printf "%s" "$OCR_TEXT" | wl-copy
  paplay "$OCR_REGION_SHUTTER_SOUND"
  notify-send \
    "OCR Text Copied" \
    "Detected with: $DETECTION_METHOD" \
    --app-name="hyprland" \
    --category="action" \
    --icon="edit-copy"
fi
