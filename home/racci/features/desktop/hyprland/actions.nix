{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe concatStringsSep attrsToLuaInlineArgs;

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
        trap 'rm -f "$TEMP_FILE" "$PROCESSED_FILE"' EXIT;

        GRIMBLAST_HIDE_CURSOR=1 grimblast --freeze save area "$TEMP_FILE";

        # upscale 3x, greyscale, sharpen, normalise contrast, and adds a 10px border.
        # This significantly improves recognition on small or low-DPI captures.
        convert "$TEMP_FILE" \
          -resize 300% \
          -colorspace Gray \
          -sharpen 0x1 \
          -contrast-stretch 0.15%x0.15% \
          -bordercolor White \
          -border 10x10 \
          "$PROCESSED_FILE";

        TESSDATA_PREFIX="${tessdata}" tesseract \
          --oem 1 \
          --psm 1 \
          "$PROCESSED_FILE" - -l eng jpn osd | wl-copy;

        paplay ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/camera-shutter.oga;

        notify-send \
          "OCR Text Copied" \
          "Text copied to clipboard" \
          --app-name="hyprland" \
          --category="action" \
          --icon="edit-copy";
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

    settings.bind = attrsToLuaInlineArgs {
      "SUPER+SHIFT+T" = ''hl.dsp.exec_cmd("${ocrRegion}")'';
      "SUPER+SHIFT+C" = ''hl.dsp.exec_cmd("${colourPicker}")'';
      "Print" = ''hl.dsp.exec_cmd("${screenshot} area")'';
      "SUPER+Print" = ''hl.dsp.exec_cmd("${screenshot} output")'';
      "CTRL+SHIFT+ALT+Delete" =
        ''hl.dsp.exec_cmd("pkill ${pkgs.wlogout}/bin/wlogout || ${pkgs.wlogout}/bin/wlogout -p layer-shell")'';
      "CTRL+SHIFT+SPACE" = ''hl.dsp.exec_cmd("${pkgs._1password-gui}/bin/1password --quick-access")'';
    };

    custom-settings.lua.applicationBinds = {
      "SUPER+T" = "${pkgs.alacritty}/bin/alacritty";
      "SUPER+F" = "${pkgs.firefox}/bin/firefox";
      "SUPER+SHIFT+E" = "${pkgs.nautilus}/bin/nautilus --new-window";
    };
  };
}
