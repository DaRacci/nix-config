{ config, inputs, pkgs, lib, ... }: with lib; let cfg = config.custom.theme; in {
  imports = [
    inputs.nix-colours.homeManagerModules.default
  ];

  options.custom.theme = {
    enable = mkEnableOption "Theming" // { default = true; };

    colourScheme = mkOption {
      type = types.enum (lib.attrNames inputs.nix-colours.colourSchemes);
      default = "onedark";
    }

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

  config = mkIf cfg.enable (let nix-colours-lib = nix-colours.lib.contrib { inherit pkgs; }; in rec {
    home.packages = with pkgs; [
      twemoji-color-font
      noto-fonts-emoji
    ];

    colorScheme = nix-colours.colorSchemes.${cfg.colourScheme};

    gtk = {
      enable = true;

      theme = {
        name = cfg.colourScheme;
        package = nix-colours-lib.gtkThemeFromScheme;
      };

      iconTheme = {
        name = "Adwaita";
        package = pkgs.gnome.adwaita-icon-theme;
      };

      cursorTheme = {
        inherit (cfg.cursor) name size package;
      };
    };

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
      "hyprctl setcursor ${cfg.cusor.name} ${cfg.cursor.size}"
    ];

    programs.alacritty.settings = mkIf config.programs.alacritty.enable {
      colors = {
        draw_bold_text_with_bright_colors = true;

        primary = {
          background = "${colorScheme.base00}";
          foreground = "${colorScheme.base05}";
        };

        cursor = {
          text = "${colorScheme.base00}";
          cursor = "${colorScheme.base05}";
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
        }
      };
    };
  });
}