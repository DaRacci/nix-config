{
  pkgs,
  lib,
  ...
}:
let
  uwsmExec = slice: exec: "${lib.getExe' pkgs.uwsm "uwsm-app"} -s ${slice} -- ${exec}";
  hdropExe = lib.getExe pkgs.hdrop;
  mkDropdown =
    {
      bind,
      exec,
      class,
      rule ? { },
    }:
    {
      wayland.windowManager.hyprland = {
        custom-settings = {
          bind.${bind} = [
            "exec"
            "${uwsmExec "b" "${hdropExe} --background --floating --class ${class} ${exec}"}"
          ];
          windowrule = [
            {
              matcher.class = "^${class}$";
              rule = lib.mkMerge [
                {
                  float = lib.mkDefault true;
                  pin = lib.mkDefault true;
                  size = lib.mkDefault "33%";
                  move = lib.mkDefault {
                    x = lib.mkDefault "33%";
                    y = lib.mkDefault "67";
                  };
                }
                rule
              ];
            }
          ];
        };

        settings.exec-once = [
          (uwsmExec "b" "${hdropExe} --background --floating --class ${class} ${exec}")
        ];
      };
    };

in
lib.mkMerge [
  (mkDropdown {
    bind = "SUPER+b";
    exec = lib.getExe pkgs.bitwarden;
    class = "Bitwarden";
  })
  (mkDropdown {
    bind = "SUPER+c";
    exec = lib.getExe pkgs.gnome-calculator;
    class = "org.gnome.Calculator";
    rule = {
      size = {
        width = "19%";
        height = "33%";
      };
      move.x = "40%";
    };
  })
]
