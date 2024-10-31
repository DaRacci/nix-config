{ config, pkgs, ... }:
let
  screenshotsPath = "${config.xdg.userDirs.pictures}/Screenshots";

  mkScript = name: content: "${pkgs.writeShellApplication {
    name = "screenshot-select-${name}";
    runtimeInputs = [ pkgs.grimblast pkgs.satty ];
    text = ''
      datedFolder="${screenshotsPath}/$(date '+%Y/%m')";
      savePath="''${datedFolder}/Screenshot_$(date '+%Y%m%d_%H%M%S')";
      savePathAnnotated="''${savePath}_annotated.png";
      savePath="''${savePath}.png";

      mkdir -p "''${datedFolder}";

      ${content}
    '';
  }}/bin/screenshot-select-${name}";

  scriptArea = mkScript "area" ''
    grimblast --notify --freeze copysave area "$savePath";
    satty --filename "''${savePath}" --fullscreen --output-filename "''${savePathAnnotated}";
  '';

  scriptOutput = mkScript "output" ''
    grimblast --notify --freeze copysave output "$savePath";
    satty --filename "''${savePath}" --fullscreen --output-filename "''${savePathAnnotated}";
  '';
in
{
  # TODO - Screenshot sound
  wayland.windowManager.hyprland.extraConfig = ''
    bind=,Print,exec,${scriptArea}
    bind=SUPER,Print,exec,${scriptOutput}
  '';
}
