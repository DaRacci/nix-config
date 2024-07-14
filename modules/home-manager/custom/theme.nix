{ nix-colors, config, inputs, pkgs, lib, ... }: with lib; let
  inherit (nix-colors.lib.conversions) hexToRGB;
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

  config = mkIf cfg.enable (
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
        rofi = {
          theme =
            let
              inherit (lib.formats.rasi) mkLiteral;
              toRGBA = hex: alpha: let rgb = hexToRGB hex; in mkLiteral "rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, ${alpha}%)";
            in
            ''
              * {
                red = ${toRGBA colorScheme.base08 100};
                blue = ${toRGBA colorScheme.base0D 100};
                lightfg = ${toRGBA colorScheme.base06 100};
                lightbg = ${toRGBA colorScheme.base01 100};
                foreground = ${toRGBA colorScheme.base05 100};
                background = ${toRGBA colorScheme.base00 100};
                backgronud-color = ${toRGBA colorScheme.base00 0};

                separatorcolor:              @foreground;
                border-color:                @foreground;
                selected-normal-foreground:  @lightbg;
                selected-normal-background:  @lightfg;
                selected-active-foreground:  @background;
                selected-active-background:  @blue;
                selected-urgent-foreground:  @background;
                selected-urgent-background:  @red;
                normal-foreground:           @foreground;
                normal-background:           @background;
                active-foreground:           @blue;
                active-background:           @background;
                urgent-foreground:           @red;
                urgent-background:           @background;
                alternate-normal-foreground: @foreground;
                alternate-normal-background: @lightbg;
                alternate-active-foreground: @blue;
                alternate-active-background: @lightbg;
                alternate-urgent-foreground: @red;
                alternate-urgent-background: @lightbg;
                spacing:                     2;
              }
              window {
                  background-color: @background;
                  border:           1;
                  padding:          5;
              }
              mainbox {
                  border:           0;
                  padding:          0;
              }
              message {
                  border:           1px dash 0px 0px ;
                  border-color:     @separatorcolor;
                  padding:          1px ;
              }
              textbox {
                  text-color:       @foreground;
              }
              listview {
                  fixed-height:     0;
                  border:           2px dash 0px 0px ;
                  border-color:     @separatorcolor;
                  spacing:          2px ;
                  scrollbar:        true;
                  padding:          2px 0px 0px ;
              }
              element-text, element-icon {
                  background-color: inherit;
                  text-color:       inherit;
              }
              element {
                  border:           0;
                  padding:          1px ;
              }
              element normal.normal {
                  background-color: @normal-background;
                  text-color:       @normal-foreground;
              }
              element normal.urgent {
                  background-color: @urgent-background;
                  text-color:       @urgent-foreground;
              }
              element normal.active {
                  background-color: @active-background;
                  text-color:       @active-foreground;
              }
              element selected.normal {
                  background-color: @selected-normal-background;
                  text-color:       @selected-normal-foreground;
              }
              element selected.urgent {
                  background-color: @selected-urgent-background;
                  text-color:       @selected-urgent-foreground;
              }
              element selected.active {
                  background-color: @selected-active-background;
                  text-color:       @selected-active-foreground;
              }
              element alternate.normal {
                  background-color: @alternate-normal-background;
                  text-color:       @alternate-normal-foreground;
              }
              element alternate.urgent {
                  background-color: @alternate-urgent-background;
                  text-color:       @alternate-urgent-foreground;
              }
              element alternate.active {
                  background-color: @alternate-active-background;
                  text-color:       @alternate-active-foreground;
              }
              scrollbar {
                  width:            4px ;
                  border:           0;
                  handle-color:     @normal-foreground;
                  handle-width:     8px ;
                  padding:          0;
              }
              sidebar {
                  border:           2px dash 0px 0px ;
                  border-color:     @separatorcolor;
              }
              button {
                  spacing:          0;
                  text-color:       @normal-foreground;
              }
              button selected {
                  background-color: @selected-normal-background;
                  text-color:       @selected-normal-foreground;
              }
              inputbar {
                  spacing:          0px;
                  text-color:       @normal-foreground;
                  padding:          1px ;
                  children:         [ prompt,textbox-prompt-colon,entry,case-indicator ];
              }
              case-indicator {
                  spacing:          0;
                  text-color:       @normal-foreground;
              }
              entry {
                  spacing:          0;
                  text-color:       @normal-foreground;
              }
              prompt {
                  spacing:          0;
                  text-color:       @normal-foreground;
              }
              textbox-prompt-colon {
                  expand:           false;
                  str:              ":";
                  margin:           0px 0.3000em 0.0000em 0.0000em ;
                  text-color:       inherit;
              }
            '';
        };
      };
    }
  );
}
