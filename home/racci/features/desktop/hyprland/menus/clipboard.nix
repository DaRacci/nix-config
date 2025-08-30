{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe getExe';
in
{
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER,V,exec,${getExe' pkgs.uwsm "uwsm-app"} -s a -- ~/.local/bin/rofi-clipboard"
  ];

  home.packages = with pkgs; [
    wl-clipboard
  ];

  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  xdg.configFile."rofi/clipboard.rasi".text = ''
    @import "~/.config/rofi/config.rasi"

    configuration {
      modi: "drun";
      show-icons: false;
    }

    // Main //
    window {
      fullscreen: false;
      enabled: true;
      cursor: "default";
    }
    mainbox {
        enabled: true;
        spacing: 0em;
        padding: 0.5em;
        orientation: vertical;
        children: [ "wallbox" , "listbox" ];
        background-color: transparent;
    }
    wallbox {
      spacing: 0em;
      padding: 0em;
      expand: false;
      orientation: horizontal;
      background-color: transparent;
      children: [ "wallframe" , "inputbar" ];
    }
    wallframe {
      width: 5em;
      spacing: 0em;
      padding: 0em;
      expand: false;
    }

    // Inputs //
    icon-ib {
      expand: false;
      filename: "system-search";
      vertical-align: 0.5;
      horizontal-align: 0.5;
      size: 1em;
    }
    inputbar {
      enabled: true;
      padding: 0em;
      children: [ "entry" ];
      background-color: @alternate-normal-background;
      expand: true;
      children: [ "icon-ib" , "entry" ];
    }
    entry {
      enabled: true;
      padding: 1.8em;
      background-color: transparent;
    }

    // Lists //
    listbox {
        spacing: 0em;
        padding: 0em;
        orientation: vertical;
        children: [ "dummy" , "listview" , "dummy" ];
        background-color: transparent;
    }
    listview {
        enabled: true;
        padding: 0.5em;
        columns: 1;
        lines: 11;
        cycle: true;
        fixed-height: true;
        fixed-columns: false;
        expand: false;
        cursor: "default";
        background-color: transparent;
    }
    dummy {
        spacing: 0em;
        padding: 0em;
        background-color: transparent;
    }

    // Elements //
    element {
        enabled: true;
        padding: 0.5em;
        cursor: pointer;
        background-color: transparent;
        children: [ "element-icon" , "element-text" ];
    }
    element-text {
      vertical-align: 0.0;
      horizontal-align: 0.0;
      cursor: inherit;
      background-color: transparent;
      text-color: inherit;
    }

    icon-current-entry {
      expand: true;
      size: 80%;
    }
  '';

  home.file.".local/bin/rofi-clipboard".source = getExe (
    pkgs.writeShellApplication {
      name = "rofi-clipboard";
      runtimeInputs = with pkgs; [
        config.services.cliphist.package
        config.programs.rofi.finalPackage
        wtype
        ripgrep
        wl-clipboard
        libnotify
        gawk
      ];
      text = ''
        del_mode=false
        paste_mode=false

        notify() {
          local summary="$1"
          local body="''${2:-}"
          local icon="''${3:-edit-paste}"

          notify-send "$summary" "$body" \
            -a "Cliphist" \
            --icon="$icon" \
            --urgency=low \
            --expire-time=2000
        }

        paste_string() {
          hyprctl -q dispatch exec 'wtype -M ctrl V -m ctrl'
        }

        process_selections() {
          mapfile -t lines #! Not POSIX compliant
          total_lines=''${#lines[@]}

          [ "$total_lines" -eq 0 ] && return 0

          case "''${lines[0]}" in
            ":w:i:p:e:"*)
              "$0" --wipe
              return 0
              ;;
          esac

          local output=""
          local deleted_items=()
          for ((i = 0; i < total_lines; i++)); do
            local line="''${lines[$i]}"

            if [[ "$del_mode" = true ]]; then
              cliphist delete <<<"$line"
              deleted_items+=("$line")
            else
              local decoded_line
              decoded_line="$(echo -e "$line\t" | cliphist decode)"
              if [ $i -lt $((total_lines - 1)) ]; then
                printf -v output '%s%s\n' "$output" "$decoded_line"
              else
                printf -v output '%s%s' "$output" "$decoded_line"
              fi
            fi
          done

          if [ "$del_mode" = true ]; then
            if [ ''${#deleted_items[@]} -gt 0 ]; then
              local deleted_count=''${#deleted_items[@]}

              local summary
              local body
              if [[ "$deleted_count" -gt 1 ]]; then
                summary="Deleted $deleted_count items"
                body=""

                for ((i = 0; i < deleted_count; i++)); do
                  local item="''${deleted_items[$i]}"
                  local colour
                  if [ "$(("$i" % 2))" = "0" ]; then
                    colour=${config.lib.stylix.colors.base05}
                  else
                    colour=${config.lib.stylix.colors.base04}
                  fi

                  body="$body\n<span foreground=\"#$colour\">$item</span>"
                done
              else
                summary="Deleted"
                body="<span foreground=\"#${config.lib.stylix.colors.base05}\">''${deleted_items[0]}</span>"
              fi

              notify "$summary" "$body" "edit-delete"
            fi
          else
            echo -n "$output"
          fi
        }

        check_content() {
          local line
          read -r line
          if [[ "$line" == *"[[ binary data"* ]]; then
            cliphist decode <<<"$line" | wl-copy
            local img_idx
            img_idx=$(awk -F '\t' '{print $1}' <<<"$line")
            local temp_preview="$XDG_CACHE_HOME/pastebin-preview_$img_idx"
            wl-paste >"$temp_preview"
            notify-send -a "Pastebin:" "Preview: $img_idx" -i "$temp_preview" -t 2000
            return 1
          fi
        }

        run_rofi() {
          local placeholder="$1"
          shift

          rofi -dmenu \
            -theme-str "entry { placeholder: \"$placeholder\";}" \
            -config ~/.config/rofi/clipboard.rasi \
            "$@"
        }

        # display clipboard history and copy selected item
        show_history() {
          local selected_item
          selected_item=''$( (
            echo -e ":w:i:p:e:\t☢️ Clear Clipboard History"
            cliphist list
          ) | run_rofi " 📜 History..." \
            -multi-select -i -display-columns 2 -selected-row 1 \
            -ballot-selected-str " " -ballot-unselected-str " " \
            -kb-custom-1 "Control+Delete" -kb-custom-2 "Control+Return" -kb-accept-custom ""
          )
          LASTEXITCODE=$?

          [ -n "$selected_item" ] || exit 0

          if [ $LASTEXITCODE -eq 10 ]; then
            del_mode=true
          elif [ $LASTEXITCODE -eq 11 ]; then
            paste_mode=true
          fi

          if echo -e "$selected_item" | check_content; then
            process_selections <<<"$selected_item" | wl-copy
            if [ "$paste_mode" = true ]; then
              paste_string "''${@}"
            fi

            echo -e "$selected_item\t" | cliphist delete
          else
            # binary content - handled by check_content
            paste_string "''${@}"
            exit 0
          fi
        }

        clear_history() {
          local confirm
          confirm=''$(echo -e "Yes\nNo" | run_rofi "☢️ Clear Clipboard History?")

          if [ "$confirm" = "Yes" ]; then
            cliphist wipe
            notify "Clipboard" "History cleared"
          else
            "$0" --list
          fi
        }

        show_help() {
            cat <<EOF
        Options:
          -l  | --list   | History            Show clipboard history and copy selected item
          -d  | --delete | Delete             Delete selected item from clipboard history
          -w  | --wipe   | Clear History      Clear clipboard history
          -h  | --help   | Help               Display this help message

        EOF
            exit 0
        }

        main() {
          local action
          if [ $# -eq 0 ]; then
            action="History"
          else
            action="$1"
            shift
          fi

          case "$action" in
            -l | --list | "History")
              show_history "$@"
              ;;
            -w | --wipe)
              clear_history
              ;;
            -h | --help | *)
              show_help
              ;;
          esac
        }

        main "$@"
      '';
    }
  );

  systemd.user.services = rec {
    cliphist.Unit.After = [ "graphical-session.target" ];
    cliphist-images = cliphist;
  };

  custom.uwsm.sliceAllocation.background = [
    "cliphist"
    "cliphist-images"
  ];
}
