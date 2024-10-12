{ pkgs, lib, ... }: {
  wayland.windowManager.hyprland.settings =
    let
      wlogout = lib.getExe pkgs.wlogout;
    in
    {
      bind = [
        "Ctrl+Shift+Alt, Delete, exec, pkill ${wlogout} || ${wlogout} -p layer-shell"
      ];
    };

  programs.wlogout = {
    enable = true;

    style = /*css*/ ''
      * {
        all: unset;
        background-image: none;
        transition: 400ms cubic-bezier(0.05, 0.7, 0.1, 1);
      }

      window {
        background: rgba(0, 0, 0, 0.5);
      }

      button {
        font-family: 'Material Symbols Outlined';
        font-size: 10rem;
        background-color: rgba(11, 11, 11, 0.4);
        color: #FFFFFF;
        margin: 2rem;
        border-radius: 2rem;
        padding: 3rem;
      }

      button:focus,
      button:active,
      button:hover {
        background-color: rgba(51, 51, 51, 0.5);
        border-radius: 4rem;
      }
    '';

    layout = [
      {
        label = "lock";
        text = "lock";
        keybind = "l";
        action = "loginctl lock-session";
      }
      {
        label = "hibernate";
        text = "save";
        keybind = "h";
        action = "systemctl hiberante || loginctl hibernate";
      }
      {
        label = "logout";
        text = "logout";
        keybind = "e";
        action = "pkill Hyprland || loginctl terminate-user $USER";
      }
      {
        label = "shutdown";
        text = "power_settings_new";
        keybind = "s";
        action = "systemctl poweroff || loginctl poweroff";
      }
      {
        label = "suspend";
        text = "bedtime";
        keybind = "u";
        action = "systemctl suspend || loginctl suspend";
      }
      {
        label = "reboot";
        text = "restart_alt";
        keybind = "r";
        action = "systemctl reboot || loginctl reboot";
      }
    ];
  };
}
