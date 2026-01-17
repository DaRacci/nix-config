{
  pkgs,
  lib,
  ...
}:
{
  wayland.windowManager.hyprland = {
    custom-settings = {
      windowrule = {
        pictureInPicture = {
          matcher = [ { title = "^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$"; } ];
          rule = {
            keepAspectRatio = true;
            float = true;
            pin = true;
            opacity = 1.0;
            move = {
              x = "73%";
              y = "72%";
            };
          };
        };

        trippleMonitor = {
          matcher = [
            { title = "^(Assetto Corsa)$"; }
            { title = "^(AC2)$"; }
          ];
          rule = {
            float = true;
            center = true;
            rounding = 0;
            opacity = 1.0;
            size = "7680x1440";
          };
        };

        popupModal = {
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
            { class = "^(takecontrolrdviewer.exe)$"; } # Take Control Viewer
          ];
          rule.float = true;
        };

        # Sending shit to the shadow realm
        stupidWindows = {
          matcher = [
            {
              initialTitle = "(${lib.strings.escapeRegex " - Connecting [v. ${pkgs.take-control-viewer.version}] [0:00:00]"})$";
            }
          ];
          rule.workspace.special = "special";
        };

        centeredPopupModal = {
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
        };

        steamClient = {
          matcher = [
            { class = "^((?i)steam)$"; }
            { class = "^(steamwebhelper)$"; }
          ];
          rule = {
            float = true;
            borderSize = 0;
            noShadow = true;
            noBlur = true;
          };
        };

        games = {
          matcher = [
            { class = "^(gamescope)$"; }
            { class = "^(steam_app_.*)$"; }
            { class = "^(osu!)$"; }
          ];
          rule = {
            content = "game";
            idleInhibit = "always";
            immediate = true;
            allowsInput = true;
            renderUnfocused = true;
          };
        };

        sensitiveWindows = {
          matcher = [
            { class = "^(1Password)$"; }
            { class = "^(Bitwarden)$"; }
          ];
          rule.noScreenShare = true;
        };

        dropdownMenus = {
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
        };
      };
    };
  };
}
