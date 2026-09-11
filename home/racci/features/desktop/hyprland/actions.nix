{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe concatStringsSep;

  tessdata = pkgs.stdenv.mkDerivation {
    name = "tessdata-multilang";
    buildCommand = ''
      mkdir $out
      ${concatStringsSep "\n" (
        map (lang: "cp ${lang} $out/${lang.name}") (
          with pkgs.tesseract.passthru.languages;
          [
            eng
            jpn
            osd
          ]
        )
      )}
    '';
  };

  ocrRegion = getExe (
    pkgs.writeShellApplication {
      name = "ocrRegion";
      runtimeInputs = [
        pkgs.uutils-coreutils-noprefix
        pkgs.grimblast
        pkgs.tesseract
        pkgs.imagemagick
        pkgs.wl-clipboard
        pkgs.pulseaudio
        pkgs.sound-theme-freedesktop
        pkgs.libnotify
      ];
      text = ''
        TEMP_FILE="$(mktemp --suffix=.png)";
        PROCESSED_FILE="$(mktemp --suffix=.png)";
        BINARIZED_FILE="$(mktemp --suffix=.png)";
        trap 'rm -f "$TEMP_FILE" "$PROCESSED_FILE" "$BINARIZED_FILE"' EXIT;

        GRIMBLAST_HIDE_CURSOR=1 grimblast --freeze save area "$TEMP_FILE";

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
          "$PROCESSED_FILE";
        IMAGE_DIMS=$(identify -format "%wx%h" "$PROCESSED_FILE" 2>&1 || echo "unknown");

        try_ocr() {
          local psm="$1";
          local image_file="$2";
          local result;
          result=$(TESSDATA_PREFIX="${tessdata}" tesseract \
            --oem 1 \
            --psm "$psm" \
            "$image_file" - -l eng jpn osd 2>&1);
          trim_whitespace "$result";
        }

        trim_whitespace() {
          printf "%s" "$1" | tr -d '[:space:]';
        }

        # Try OCR with different PSM modes, falling back to binarisation at each mode if no text is detected.
        OCR_TEXT="";
        DETECTION_METHOD="";
        for psm in 1 3 6; do
          OCR_TEXT=$(try_ocr "$psm" "$PROCESSED_FILE");
          if [ -n "$OCR_TEXT" ]; then
            DETECTION_METHOD="PSM $psm (normal)";
            break;
          fi

          if [ ! -f "$BINARIZED_FILE" ] || [ "$psm" -eq 1 ]; then
            if [ ! -f "$BINARIZED_FILE" ]; then
              convert "$PROCESSED_FILE" -threshold 40% "$BINARIZED_FILE";
            fi
          fi

          OCR_TEXT=$(try_ocr "$psm" "$BINARIZED_FILE");
          if [ -n "$OCR_TEXT" ]; then
            DETECTION_METHOD="PSM $psm (binarized)";
            break;
          fi
        done;

        if [ -z "$OCR_TEXT" ]; then
          notify-send \
            "OCR: No Text Detected" \
            "Image: ''${IMAGE_DIMS}px" \
            --app-name="hyprland" \
            --category="action" \
            --icon="dialog-warning" \
            --urgency="normal";
        else
          printf "%s" "$OCR_TEXT" | wl-copy;
          paplay ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/camera-shutter.oga;
          notify-send \
            "OCR Text Copied" \
            "Detected with: $DETECTION_METHOD" \
            --app-name="hyprland" \
            --category="action" \
            --icon="edit-copy";
        fi
      '';
    }
  );

  screenshot = getExe (
    pkgs.writeShellApplication {
      name = "screenshot";
      runtimeInputs = [
        pkgs.grimblast
        pkgs.satty
        pkgs.pulseaudio
        pkgs.sound-theme-freedesktop
        pkgs.libnotify
      ];
      text = ''
        if [ $# -ne 1 ] || [ "$1" != "area" ] && [ "$1" != "output" ]; then
          echo "Usage: screenshot <area|output>";
          exit 1;
        fi
        CAPTURE=$1;

        datedFolder="${config.xdg.userDirs.pictures}/Screenshots/$(date '+%Y/%m')";
        savePath="''${datedFolder}/Screenshot_$(date '+%Y%m%d_%H%M%S')";
        savePathAnnotated="''${savePath}_annotated.png";
        savePath="''${savePath}.png";
        mkdir -p "''${datedFolder}";

        GRIMBLAST_HIDE_CURSOR=1 grimblast --freeze copysave "$CAPTURE" "$savePath";
        paplay ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/camera-shutter.oga;

        ACTION=$(notify-send \
          "Screenshot Captured" \
          "Screenshot saved at $savePath" \
          --app-name="hyprland" \
          --category="action" \
          --icon="$savePath" \
          --app-name="Screenshot" \
          --action=Open \
          --action=Edit);

        if [ "$ACTION" = 0 ]; then
          xdg-open "$savePath";
        elif [ "$ACTION" = 1 ]; then
          satty --filename "''${savePath}" --fullscreen --output-filename "''${savePathAnnotated}";
        fi
      '';
    }
  );

  # TODO: Allow zooming in and out with mouse wheel
  colourPicker = getExe (
    pkgs.writeShellApplication {
      name = "colourPicker";
      runtimeInputs = with pkgs; [
        hyprpicker
        wl-clipboard
        hyprland
        gojq
      ];
      text = ''
        sensitivityBefore=$(hyprctl getoption input:sensitivity -j | gojq -r '.float');
        hyprctl keyword input:sensitivity -0.8;
        hyprpicker --render-inactive --autocopy;
        hyprctl keyword input:sensitivity "$sensitivityBefore";
      '';
    }
  );
in
{
  wayland.windowManager.hyprland = {
    custom-settings.permission.screenCopy = [
      pkgs.grim
      pkgs.hyprpicker
      pkgs.slurp
    ];

    custom-settings.lua = {
      luaModules = [ ./lua/actions.lua ];
      variables = {
        inherit ocrRegion;
        inherit colourPicker;
        screenshotArea = "${screenshot} area";
        screenshotOutput = "${screenshot} output";
        quickAccessCmd = "${pkgs._1password-gui}/bin/1password --quick-access";
        wlogoutCmd = "pkill ${pkgs.wlogout}/bin/wlogout || ${pkgs.wlogout}/bin/wlogout -p layer-shell";
      };
      applicationBinds = {
        "SUPER+T" = "${pkgs.alacritty}/bin/alacritty";
        "SUPER+F" = "${pkgs.firefox}/bin/firefox";
        "SUPER+SHIFT+E" = "${pkgs.nautilus}/bin/nautilus --new-window";
      };
    };
  };
}
