{ lib, config, ... }: with lib; let
  mkFontOption = kind: defFamily: defSize: defPackage: {
    family = lib.mkOption {
      type = lib.types.str;
      default = defFamily;
      description = "Family name for ${kind} font profile";
      example = "Fira Code";
    };

    size = lib.mkOption {
      type = lib.types.number;
      default = defSize;
      description = "The common size that is used for this font";
      example = "16";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = defPackage;
      description = "Package for ${kind} font profile";
      example = "pkgs.fira-code";
    };
  };
  cfg = config.custom.fontProfiles;
in
{
  options.custom.fontProfiles = {
    enable = lib.mkEnableOption "Whether to enable font profiles";
    monospace = mkFontOption "monospace" "JetBrainsMono Nerd Font" 18 (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; });
    regular = mkFontOption "regular" "Inter" 16 pkgs.inter;
    emoji = mkFontOption "emoji" "Noto Color Emoji" cfg.regular.size pkgs.noto-fonts-color-emoji;
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.monospace.family != null;
        message = "monospace.family must be set";
      }
      {
        assertion = cfg.monospace.size != null;
        message = "monospace.size must be set";
      }
      {
        assertion = cfg.monospace.package != null;
        message = "monospace.package must be set";
      }
      {
        assertion = cfg.regular.family != null;
        message = "regular.family must be set";
      }
      {
        assertion = cfg.regular.size != null;
        message = "regular.size must be set";
      }
      {
        assertion = cfg.regular.package != null;
        message = "regular.package must be set";
      }
      {
        assertion = cfg.emoji.family != null;
        message = "emoji.family must be set";
      }
      {
        assertion = cfg.emoji.size != null;
        message = "emoji.size must be set";
      }
      {
        assertion = cfg.emoji.package != null;
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

      mako.font = with cfg.monospace; "${family} ${toString size}";
    };

    home.packages = builtins.map (profile: profile.package) (with cfg; [
      monospace
      regular
      emoji
    ]);
  };
}
