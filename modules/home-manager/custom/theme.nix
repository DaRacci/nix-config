{ inputs, config, pkgs, lib, ... }: with lib; let
  cfg = config.custom.theme;
in
{
  imports = [
    inputs.nix-colours.homeManagerModules.default
  ];

  options.custom.theme = {
    enable = mkEnableOption "Theming" // { default = true; };

    colourScheme = mkOption {
      type = types.enum (lib.attrNames inputs.nix-colours.colorSchemes);
      default = "onedark";
    };

    cursor = {
      name = mkOption {
        type = types.str;
        default = "Bibata-Modern-Ice";
      };

      size = mkOption {
        type = types.int;
        default = 32;
      };

      package = mkOption {
        type = types.package;
        default = pkgs.bibata-cursors;
      };
    };
  };

  config = mkIf cfg.enable
    (
      let nix-colours-lib = inputs.nix-colours.lib.contrib { inherit pkgs; }; in rec {
        home.packages = with pkgs; [
          twemoji-color-font
          noto-fonts-emoji
        ];

        colorScheme = inputs.nix-colours.colorSchemes.${cfg.colourScheme};

        gtk = {
          enable = true;

          theme = {
            name = colorScheme.slug;
            package = nix-colours-lib.gtkThemeFromScheme { scheme = colorScheme; };
          };

          iconTheme = {
            name = "Adwaita";
            package = pkgs.gnome.adwaita-icon-theme;
          };

          cursorTheme = {
            inherit (cfg.cursor) name size package;
          };
        };

        dconf.settings."org/gnome/desktop/interface".color-scheme =
          if (config.colorScheme.variant == "dark")
          then "prefer-dark"
          else if (colorScheme.variant == "light")
          then "prefer-light"
          else throw "Unable to determine light or dark preference, got ${config.colorScheme.variant}";

        services.xsettingsd = {
          enable = true;
          settings = {
            "Net/ThemeName" = "${gtk.theme.name}";
            "Net/IconThemeName" = "${gtk.iconTheme.name}";
          };
        };

        home.pointerCursor = {
          inherit (cfg.cursor) name size package;
        };

        qt = {
          enable = true;
          platformTheme.name = "gtk3";
          style.name = "adwaita-qt6";
        };

        wayland.windowManager.hyprland.settings.exec-once = mkIf config.wayland.windowManager.hyprland.enable [
          "hyprctl setcursor ${cfg.cursor.name} ${toString cfg.cursor.size}"
        ];

        programs = {
          alacritty.settings = mkIf config.programs.alacritty.enable {
            colors = {
              draw_bold_text_with_bright_colors = true;

              primary = {
                background = colorScheme.base00;
                foreground = colorScheme.base05;
              };

              cursor = {
                text = colorScheme.base00;
                cursor = colorScheme.base05;
              };

              normal = {
                black = colorScheme.base00;
                red = colorScheme.base08;
                green = colorScheme.base0B;
                yellow = colorScheme.base0A;
                blue = colorScheme.base0D;
                magenta = colorScheme.base0E;
                cyan = colorScheme.base0C;
                white = colorScheme.base05;
              };

              bright = {
                black = colorScheme.base03;
                red = colorScheme.base08;
                green = colorScheme.base0B;
                yellow = colorScheme.base0A;
                blue = colorScheme.base0D;
                magenta = colorScheme.base0E;
                cyan = colorScheme.base0C;
                white = colorScheme.base05;
              };

              indexed_colors = {
                index = 16;
                color = colourScheme.base09;
              };
            };
          };

          # Based on https://github.com/tinted-theming/base16-rofi/blob/0353f5c9e1ba2efa4422f05f416ea87e5d0521b8/templates/default.mustache
          rofi.theme =
            let
              inherit (config.lib.formats.rasi) mkLiteral;
              inherit (inputs.nix-colours.lib.conversions) hexToRGBString;
              toRGBA = hex: alpha: mkLiteral "rgba(${hexToRGBString "," hex},${toString alpha}%)";
            in
            {
              "*" = {
                red = toRGBA colorScheme.palette.base08 100;
                blue = toRGBA colorScheme.palette.base0D 100;
                lightfg = toRGBA colorScheme.palette.base06 100;
                lightbg = toRGBA colorScheme.palette.base01 100;
                foreground = toRGBA colorScheme.palette.base05 100;
                background = toRGBA colorScheme.palette.base00 100;
                background-color = toRGBA colorScheme.palette.base00 0;

                separatorcolor = mkLiteral "@foreground";
                border-color = mkLiteral "@foreground";
                selected-normal-foreground = mkLiteral "@lightbg";
                selected-normal-background = mkLiteral "@lightfg";
                selected-active-foreground = mkLiteral "@background";
                selected-active-background = mkLiteral "@blue";
                selected-urgent-foreground = mkLiteral "@background";
                selected-urgent-background = mkLiteral "@red";
                normal-foreground = mkLiteral "@foreground";
                normal-background = mkLiteral "@background";
                active-foreground = mkLiteral "@blue";
                active-background = mkLiteral "@background";
                urgent-foreground = mkLiteral "@red";
                urgent-background = mkLiteral "@background";
                alternate-normal-foreground = mkLiteral "@foreground";
                alternate-normal-background = mkLiteral "@lightbg";
                alternate-active-foreground = mkLiteral "@blue";
                alternate-active-background = mkLiteral "@lightbg";
                alternate-urgent-foreground = mkLiteral "@red";
                alternate-urgent-background = mkLiteral "@lightbg";
                spacing = 2;
              };
              window = {
                background-color = mkLiteral "@background";
                border = 1;
                padding = 5;
              };
              mainbox = {
                border = 0;
                padding = 0;
              };
              message = {
                border = mkLiteral "1px dash 0px 0px";
                border-color = mkLiteral "@separatorcolor";
                padding = mkLiteral "1px";
              };
              textbox = {
                text-color = mkLiteral "@foreground";
              };
              listview = {
                fixed-height = 0;
                border = mkLiteral "2px dash 0px 0px";
                border-color = mkLiteral "@separatorcolor";
                spacing = mkLiteral "2px";
                scrollbar = true;
                padding = mkLiteral "2px 0px 0px";
              };
              "element-text, element-icon" = {
                background-color = mkLiteral "inherit";
                text-color = mkLiteral "inherit";
              };
              element = {
                border = 0;
                padding = mkLiteral "1px";
              };
              "element normal.normal" = {
                background-color = mkLiteral "@normal-background";
                text-color = mkLiteral "@normal-foreground";
              };
              "element normal.urgent" = {
                background-color = mkLiteral "@urgent-background";
                text-color = mkLiteral "@urgent-foreground";
              };
              "element normal.active" = {
                background-color = mkLiteral "@active-background";
                text-color = mkLiteral "@active-foreground";
              };
              "element selected.normal" = {
                background-color = mkLiteral "@selected-normal-background";
                text-color = mkLiteral "@selected-normal-foreground";
              };
              "element selected.urgent" = {
                background-color = mkLiteral "@selected-urgent-background";
                text-color = mkLiteral "@selected-urgent-foreground";
              };
              "element selected.active" = {
                background-color = mkLiteral "@selected-active-background";
                text-color = mkLiteral "@selected-active-foreground";
              };
              "element alternate.normal" = {
                background-color = mkLiteral "@alternate-normal-background";
                text-color = mkLiteral "@alternate-normal-foreground";
              };
              "element alternate.urgent" = {
                background-color = mkLiteral "@alternate-urgent-background";
                text-color = mkLiteral "@alternate-urgent-foreground";
              };
              "element alternate.active" = {
                background-color = mkLiteral "@alternate-active-background";
                text-color = mkLiteral "@alternate-active-foreground";
              };
              scrollbar = {
                width = mkLiteral "4px";
                border = 0;
                handle-color = mkLiteral "@normal-foreground";
                handle-width = mkLiteral "8px";
                padding = 0;
              };
              sidebar = {
                border = mkLiteral "2px dash 0px 0px";
                border-color = mkLiteral "@separatorcolor";
              };
              button = {
                spacing = 0;
                text-color = mkLiteral "@normal-foreground";
              };
              "button selected" = {
                background-color = mkLiteral "@selected-normal-background";
                text-color = mkLiteral "@selected-normal-foreground";
              };
              inputbar = {
                spacing = mkLiteral "0px";
                text-color = mkLiteral "@normal-foreground";
                padding = mkLiteral "1px";
                children = [ "prompt" "textbox-prompt-colon" "entry" "case-indicator" ];
              };
              case-indicator = {
                spacing = 0;
                text-color = mkLiteral "@normal-foreground";
              };
              entry = {
                spacing = 0;
                text-color = mkLiteral "@normal-foreground";
              };
              prompt = {
                spacing = 0;
                text-color = mkLiteral "@normal-foreground";
              };
              textbox-prompt-colon = {
                expand = false;
                str = ":";
                margin = mkLiteral "0px 0.3000em 0.0000em 0.0000em";
                text-color = mkLiteral "inherit";
              };
            };
        };
      }
    );
}








