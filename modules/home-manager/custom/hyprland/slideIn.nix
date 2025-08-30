{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    nameValuePair
    mkIf
    getExe
    getExe'
    ;
  inherit (lib.types)
    str
    attrsOf
    anything
    listOf
    enum
    submodule
    ;
  inherit (pkgs)
    hdrop
    uwsm
    ;

  windowToEdgeDistance = 5 + 2 + 8; # gap + border + padding
  barWidth = 56;

  commonOptions = {
    bind = mkOption {
      type = str;
      description = "Key binding to trigger the slide-in popup.";
    };
    exec = mkOption {
      type = str;
      description = "Command to execute for the slide-in popup.";
    };
    class = mkOption {
      type = str;
      description = "Window class for the slide-in popup.";
    };
    rule = mkOption {
      type = attrsOf anything;
      default = { };
      description = "Additional window rules for the slide-in popup.";
    };
    position = mkOption {
      type = enum [
        "left"
        "right"
        "top"
        "bottom"
        "edge"
        "side"
      ];
      default = "top";
      description = "Direction from which the popup slides in. Can be 'left', 'right', 'top', 'bottom', or 'edge' and 'side' (which will determine based on cursor position).";
    };
  };

  isEdgePosition = position: position == "edge" || position == "bottom" || position == "top";

  uwsmApp = getExe' uwsm "uwsm-app";
  hdropExe = getExe hdrop;

  invokeScript = lib.getExe (
    pkgs.writeShellApplication {
      name = "invoke-hdrop";
      runtimeInputs = with pkgs; [
        jq
        uwsm
        hdrop
      ];
      text = ''
        if [ "$#" -ne 5 ]; then
          echo "Usage: $0 <class> <exec> <position> <width> <height>"
          exit 1
        fi
        class="$1"
        exec="$2"
        position="$3"
        width="$4"
        height="$5"
        gap=${toString windowToEdgeDistance}

        if [[ "$width" == *% ]]; then
          width=''${width//%/}
        fi
        if [[ "$height" == *% ]]; then
          height=''${height//%/}
        fi

        curInfo=$(hyprctl cursorpos -j)
        monInfo=$(hyprctl monitors -j)
        activeName=$(hyprctl activeworkspace -j | jq -r .monitor)
        activeMon=$(echo "$monInfo" | jq --arg m "$activeName" '.[] | select(.name == $m)')

        if [ "$position" = "side" ]; then
          cursorX=$(echo "$curInfo" | jq '.x')
          monX=$(echo "$activeMon" | jq '.x')
          relX=$(( cursorX - monX ))
          monWidth=$(echo "$activeMon" | jq '.width')
          if [ "$relX" -le $(( monWidth / 2 )) ]; then
            position="left"
            gap=$(( gap + ${toString barWidth} ))
          else
            position="right"
          fi
        fi

        if [ "$position" = "edge" ]; then
          cursorY=$(echo "$curInfo" | jq '.y')
          monY=$(echo "$activeMon" | jq '.y')
          monHeight=$(echo "$activeMon" | jq '.height')
          relY=$(( cursorY - monY ))
          if [ "$relY" -le $(( monHeight / 2 )) ]; then
            position="top"
            gap=$(( gap + ${toString barWidth} ))
          else
            position="bottom"
          fi
        fi

        ${uwsmApp} -s b -- ${hdropExe} -f -g "$gap" -h "$height" -w "$width" -p "$position" --class "$class" "$exec"
      '';
    }
  );

  mkExec = app: "${uwsmApp} -s b -- ${hdropExe} --background --class ${app.class} ${app.exec}";

  cfg = config.wayland.windowManager.hyprland.custom-settings.slideIn;
in
{
  options.wayland.windowManager.hyprland.custom-settings.slideIn = mkOption {
    default = [ ];
    type = listOf (submodule {
      options = commonOptions;
    });
    description = "List of slide-in popups that slide in from the edge of the screen.";
  };

  config = mkIf (cfg != [ ]) {
    wayland.windowManager.hyprland = {
      settings.exec-once = map (app: mkExec app) cfg;

      custom-settings = {
        bind =
          cfg
          |> map (
            item:
            nameValuePair item.bind [
              "exec"
              (builtins.concatStringsSep " " [
                invokeScript
                item.class
                item.exec
                item.position
                (
                  if (lib.hasAttrByPath [ "size" "width" ] item.rule) && item.rule.size.width != null then
                    item.rule.size.width
                  else if (isEdgePosition item.position) then
                    "33%"
                  else
                    "20%"
                )
                (
                  if (lib.hasAttrByPath [ "size" "height" ] item.rule) && item.rule.size.height != null then
                    item.rule.size.height
                  else if (isEdgePosition item.position) then
                    "33%"
                  else
                    "98%"
                )
              ])
            ]
          )
          |> lib.listToAttrs;
      };
    };
  };
}
