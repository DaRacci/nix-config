{
  config,
  pkgs,
  lib,
  ...
}:
{
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

    style = ''
      @define-color text-colour ${config.lib.stylix.colors.base00};
      @define-color alt-text-colour ${config.lib.stylix.colors.base01};
      @define-color select-on-bg ${config.lib.stylix.colors.base0E};
      @define-color select-off-bg ${config.lib.stylix.colors.base0D};
      @define-color alt-select-on-bg ${config.lib.stylix.colors.base09};
      @define-color alt-select-off-bg ${config.lib.stylix.colors.base02};
      @define-color list-select-bg ${config.lib.stylix.colors.base0D};
      @define-color list-unselect-bg ${config.lib.stylix.colors.base03};

      * {
        background-image: none;
        font-size: ''${fntSize}px;
      }

      window {
        background-color: transparent;
      }

      button {
        color: ''${BtnCol};
        background-color: @background;
        outline-style: none;
        border: none;
        border-width: 0px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 20%;
        border-radius: 0px;
        box-shadow: none;
        text-shadow: none;
        animation: gradient_f 20s ease-in infinite;
      }

      button:focus {
        background-color: @wb-act-bg;
        background-size: 30%;
      }

      button:hover {
        background-color: @wb-hvr-bg;
        background-size: 40%;
        border-radius: ''${active_rad}px;
        animation: gradient_f 20s ease-in infinite;
        transition: all 0.3s cubic-bezier(.55,0.0,.28,1.682);
      }

      button:hover#lock {
        border-radius: ''${active_rad}px;
        margin : ''${hvr}px 0px ''${hvr}px ''${mgn}px;
      }

      button:hover#logout {
        border-radius: ''${active_rad}px;
        margin : ''${hvr}px 0px ''${hvr}px 0px;
      }

      button:hover#suspend {
        border-radius: ''${active_rad}px;
        margin : ''${hvr}px 0px ''${hvr}px 0px;
      }

      button:hover#shutdown {
        border-radius: ''${active_rad}px;
        margin : ''${hvr}px 0px ''${hvr}px 0px;
      }

      button:hover#hibernate {
        border-radius: ''${active_rad}px;
        margin : ''${hvr}px 0px ''${hvr}px 0px;
      }

      button:hover#reboot {
        border-radius: ''${active_rad}px;
        margin : ''${hvr}px ''${mgn}px ''${hvr}px 0px;
      }

      #lock {
        background-image: image(url("$HOME/.config/wlogout/icons/lock_''${BtnCol}.png"), url("/usr/share/wlogout/icons/lock.png"), url("/usr/local/share/wlogout/icons/lock.png"));
        border-radius: ''${button_rad}px 0px 0px ''${button_rad}px;
        margin : ''${mgn}px 0px ''${mgn}px ''${mgn}px;
      }

      #logout {
        background-image: image(url("$HOME/.config/wlogout/icons/logout_''${BtnCol}.png"), url("/usr/share/wlogout/icons/logout.png"), url("/usr/local/share/wlogout/icons/logout.png"));
        border-radius: 0px 0px 0px 0px;
        margin : ''${mgn}px 0px ''${mgn}px 0px;
      }

      #suspend {
        background-image: image(url("$HOME/.config/wlogout/icons/suspend_''${BtnCol}.png"), url("/usr/share/wlogout/icons/suspend.png"), url("/usr/local/share/wlogout/icons/suspend.png"));
        border-radius: 0px 0px 0px 0px;
        margin : ''${mgn}px 0px ''${mgn}px 0px;
      }

      #shutdown {
        background-image: image(url("$HOME/.config/wlogout/icons/shutdown_''${BtnCol}.png"), url("/usr/share/wlogout/icons/shutdown.png"), url("/usr/local/share/wlogout/icons/shutdown.png"));
        border-radius: 0px 0px 0px 0px;
        margin : ''${mgn}px 0px ''${mgn}px 0px;
      }

      #hibernate {
        background-image: image(url("$HOME/.config/wlogout/icons/hibernate_''${BtnCol}.png"), url("/usr/share/wlogout/icons/hibernate.png"), url("/usr/local/share/wlogout/icons/hibernate.png"));
        border-radius: 0px 0px 0px 0px;
        margin : ''${mgn}px 0px ''${mgn}px 0px;
      }

      #reboot {
        background-image: image(url("$HOME/.config/wlogout/icons/reboot_''${BtnCol}.png"), url("/usr/share/wlogout/icons/reboot.png"), url("/usr/local/share/wlogout/icons/reboot.png"));
        border-radius: 0px ''${button_rad}px ''${button_rad}px 0px;
        margin : ''${mgn}px ''${mgn}px ''${mgn}px 0px;
      }
    '';

    layout = [
      {
        label = "lock";
        text = "Lock";
        keybind = "l";
        action = "loginctl lock-session";
      }
      {
        label = "logout";
        text = "Logout";
        keybind = "e";
        action = "hyprctl dispatch exit 0 || loginctl terminate-user $USER";
      }
      {
        label = "suspend";
        text = "Suspend";
        keybind = "u";
        action = "systemctl suspend";
      }
      {
        label = "shutdown";
        text = "Shutdown";
        keybind = "s";
        action = "systemctl poweroff";
      }
      {
        label = "hibernate";
        text = "Hibernate";
        keybind = "h";
        action = "systemctl hiberante";
      }
      {
        label = "reboot";
        text = "Reboot";
        keybind = "r";
        action = "systemctl reboot";
      }
    ];
  };
}
