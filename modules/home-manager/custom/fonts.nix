{ lib, config, ... }: with lib; let
  mkFontOption = kind: {
    family = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Family name for ${kind} font profile";
      example = "Fira Code";
    };

    size = lib.mkOption {
      type = lib.types.number;
      default = null;
      description = "The common size that is used for this font";
      example = "16";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = null;
      description = "Package for ${kind} font profile";
      example = "pkgs.fira-code";
    };
  };
  cfg = config.custom.fontProfiles;
in
{
  options.custom.fontProfiles = {
    enable = lib.mkEnableOption "Whether to enable font profiles";
    monospace = mkFontOption "monospace";
    regular = mkFontOption "regular";
    emoji = mkFontOption "emoji";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        condition = cfg.monospace.family == null;
        message = "monospace.family must be set";
      }
      {
        condition = cfg.monospace.size == null;
        message = "monospace.size must be set";
      }
      {
        condition = cfg.monospace.package == null;
        message = "monospace.package must be set";
      }
      {
        condition = cfg.regular.family == null;
        message = "regular.family must be set";
      }
      {
        condition = cfg.regular.size == null;
        message = "regular.size must be set";
      }
      {
        condition = cfg.regular.package == null;
        message = "regular.package must be set";
      }
      {
        condition = cfg.emoji.family == null;
        message = "emoji.family must be set";
      }
      {
        condition = cfg.emoji.size == null;
        message = "emoji.size must be set";
      }
      {
        condition = cfg.emoji.package == null;
        message = "emoji.package must be set";
      }
    ];

    fonts.fontconfig.enable = true;

    gtk.font = {
      inherit (cfg.regular) package size;
      name = cfg.regular.family;
    };

    programs = {
      alacritty.settings.font = {
        size = cfg.monospace.size;
        normal = { inherit (cfg.monospace) family; };
      };

      vscode.userSettings = {
        "editor.fontFamily" = "'${cfg.monospace.family}', '${cfg.emoji.family}'";
        "editor.fontSize" = cfg.monospace.size;
        "editor.fontLigatures" = true;
      };

      kitty.font = { inherit (cfg.monospace) package size family; };

      rofi.font = with cfg.regular; "${family} ${toString size}";

      mako.font = with cfg.monospace; "${family} ${size}";
    };

    home.packages = builtins.map (profile: profile.package) (with cfg; [
      monospace
      regular
      emoji
    ]);
  };
}
