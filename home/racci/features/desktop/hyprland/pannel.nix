{ pkgs, ... }: {
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        output = [ "DP-1" "DP-2" "DP-3" ];
        modules-left = [ "hyprland/workspaces" "sway/mode" "wlr/taskbar" ];
        modules-center = [ "sway/window" ];
        modules-right = [ "mpd" "temperature" ];

        "hyprland/workspaces" = {
          format = "{icon}";
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
        };
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: Source Code Pro;
      }
      
      window#waybar {
        background: #16191C;
        color: #AAB2BF;
      }
      
      #workspaces button {
        padding: 0 5px;
      }
    '';
  };
}
