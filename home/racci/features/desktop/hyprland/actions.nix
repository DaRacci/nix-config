{
  config,
  pkgs,
  lib,
  ...
}:
{
  wayland.windowManager.hyprland.settings =
    let
      ocrRegion = lib.getExe (
        pkgs.writeShellApplication {
          name = "ocrRegion";
          runtimeInputs = [
            pkgs.uutils-coreutils-noprefix
            pkgs.grimblast
            pkgs.tesseract
            pkgs.wl-clipboard
            pkgs.pulseaudio
            pkgs.sound-theme-freedesktop
            pkgs.libnotify
          ];
          text = ''
            TEMP_FILE="$(mktemp --suffix=.png)";

            GRIMBLAST_HIDE_CURSOR=1 grimblast --freeze save area "$TEMP_FILE";
            tesseract "$TEMP_FILE" - | wl-copy;
            paplay ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/camera-shutter.oga;
            rm "$TEMP_FILE";

            notify-send \
              "OCR Text Copied" \
              "Text copied to clipboard" \
              --app-name="hyprland" \
              --category="action" \
              --icon="edit-copy";
          '';
        }
      );

      screenshot = lib.getExe (
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
      colourPicker = lib.getExe (
        pkgs.writeShellApplication {
          name = "colourPicker";
          runtimeInputs = with pkgs; [
            hyprpicker
            wl-clipboard
            hyprland
            gojq
          ];
          text = ''
            senitivityBefore=$(hyprctl getoption input:sensitivity -j | gojq -r '.float');
            hyprctl keyword input:sensitivity -0.8;
            hyprpicker --render-inactive --autocopy;
            hyprctl keyword input:sensitivity "$senitivityBefore";
          '';
        }
      );
    in
    {
      bind = [
        # OCR
        "Super+Shift,T,exec,${ocrRegion}"

        # Color Picker
        "Super+Shift,C,exec,${colourPicker}"

        # Screenshot
        ",Print,exec,${screenshot} area"
        "SUPER,Print,exec,${screenshot} output"
      ];

      permission = builtins.map (exe: "${lib.getExe exe},screencopy,allow") (
        with pkgs;
        [
          grim
          hyprpicker
        ]
      );
    };
}
