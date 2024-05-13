{ config, inputs, pkgs, lib, ... }: with lib; let cfg = config.custom.theme; in {
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
          name = "moreWaita";
          package = pkgs.unstable.morewaita-icon-theme;
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
        platformTheme = "gtk3";
        style.name = "adwaita-qt6";
      };

      wayland.windowManager.hyprland.settings.exec-once = mkIf config.wayland.windowManager.hyprland.enable [
        "hyprctl setcursor ${cfg.cursor.name} ${toString cfg.cursor.size}"
      ];

      programs.alacritty.settings = mkIf config.programs.alacritty.enable {
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
    }
  );
}
