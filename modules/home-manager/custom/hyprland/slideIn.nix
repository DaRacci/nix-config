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
    mkMerge
    mkDefault
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
    side = mkOption {
      type = enum [
        "left"
        "right"
        "top"
        "bottom"
      ];
      default = "top";
      description = "Direction from which the popup slides in. Can be 'left', 'right', 'top', or 'bottom'.";
    };
  };

  slideInRule = direction: {
    float = mkDefault true;
    size = {
      width = mkDefault "20%";
      height = mkDefault "97%";
    };
    move = {
      x = mkDefault "80%";
      y = mkDefault "3%";
    };
    animation = [
      "global, 1, 8, fluentDecel, slide ${direction}"
    ];
  };

  dropDownRule = direction: {
    float = mkDefault true;
    size = mkDefault "33%";
    move = {
      x = mkDefault "33%";
      y = mkDefault "67";
    };
    animation = [
      "global, 1, 8, fluentDecel, slide ${direction}"
    ];
  };

  uwsmApp = getExe' uwsm "uwsm-app";
  hdropExe = getExe hdrop;
  mkExec = exec: class: "${uwsmApp} -s b -- ${hdropExe} --background --class ${class} ${exec}";

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
      settings.exec-once = map (item: mkExec item.exec item.class) cfg;

      custom-settings = {
        bind =
          cfg
          |> map (
            item:
            nameValuePair item.bind [
              "exec"
              (mkExec item.exec item.class)
            ]
          )
          |> lib.listToAttrs;
        windowrule =
          cfg
          |> map (item: {
            matcher.class = "^${item.class}$";
            rule = mkMerge [
              ((if item.side == "left" || item.side == "right" then slideInRule else dropDownRule) item.side)
              item.rule
            ];
          });
      };
    };
  };

  # config = mkIf (false) (
  # mkMerge (mkAll config.wayland.windowManager.hyprland.custom-settings.slideIns slideInRule)
  # ++ (mkAll config.wayland.windowManager.hyprland.custom-settings.dropDowns dropDownRule)
  # );
}
