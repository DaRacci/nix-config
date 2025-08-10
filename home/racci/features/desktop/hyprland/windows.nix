_: {
  wayland.windowManager.hyprland = {
    custom-settings = {
      windowrule = [
        {
          matcher.title = "^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$";
          rule = {
            keepaspectratio = true;
            float = true;
            pin = true;
            opacity = 1.0;
            # size = "25%";
            move = {
              x = "73%";
              y = "72%";
            };
          };
        }
        {
          matcher = [
            { title = "^(Assetto Corsa)$"; }
            { title = "^(AC2)$"; }
          ];
          rule = {
            float = true;
            center = true;
            norounding = true;
            opacity = 1.0;
            size = "7680x1440";
          };
        }
        {
          matcher = [
            { class = "^(file_progress)$"; }
            { class = "^(confirm)$"; }
            { class = "^(dialog)$"; }
            { class = "^(download)$"; }
            { class = "^(notification)$"; }
            { class = "^(error)$"; }
            { class = "^(confirmreset)$"; }
            { title = "^(branchdialog)$"; }
            { title = "^(Confirm to replace files)$"; }
            { title = "^(File Operation Progress)$"; }
            { class = "^(org.pulseaudio.pavucontrol)$"; }
            { title = "^(About)$"; }
          ];
          rule.float = true;
        }
        {
          matcher = [
            { title = "^(Steam Settings)(.*)$"; }
            { title = "^(Open File)(.*)$"; }
            { title = "^(Select a File)(.*)$"; }
            { title = "^(Choose wallpaper)(.*)$"; }
            { title = "^(Open Folder)(.*)$"; }
            { title = "^(Save As)(.*)$"; }
            { title = "^(Library)(.*)$"; }
            { title = "^(File Upload)(.*)$"; }
            { title = "^(Open Firefox in Troubleshoot Mode?)$"; }
            { title = "^(MainPicker)"; } # ScreenShare Picker
          ];
          rule = {
            center = true;
            float = true;
          };
        }
        # Steam Client
        {
          matcher = [
            { class = "^((?i)steam)$"; }
            { class = "^(steamwebhelper)$"; }
          ];
          rule = {
            float = true;
            noborder = true;
            noshadow = true;
            noblur = true;
          };
        }
        # Games
        {
          matcher = [
            { class = "^(gamescope)$"; }
            { class = "^(steam_app_.*)$"; }
            { class = "^(osu!)$"; }
          ];
          rule = {
            content = "game";
            idleinhibit = "always";
            immediate = true;
            allowsInput = true;
            renderunfocused = true;
          };
        }
        # Hidden from screenshare
        {
          matcher = [
            { class = "^(1Password)$"; }
            { class = "^(Bitwarden)$"; }
          ];
          rule.noScreenshare = true;
        }
        # Panel Dropdown Menus
        {
          matcher = [
            { class = "^(org.pulseaudio.pavucontrol)$"; }
            { class = "^(\.blueman-manager-wrapped)$"; }
          ];
          rule = {
            float = true;
            size = "33%";
            move = {
              x = "63%";
              y = 67; # This is the exact position top of the window below the floating panel.
            };
          };
        }
      ];
    };
  };
}
