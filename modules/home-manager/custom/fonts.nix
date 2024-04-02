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
    fonts.fontconfig.enable = true;

    gtk.font = {
      inherit (cfg.regular) package size;
      name = cfg.regular.family;
    };

    programs.kitty.font = {
      inherit (cfg.monospace) package size;
      inherit (cfg.monospace) name;
    };

    programs.rofi.font = with cfg.regular; "${family} ${toString size}";

    # programs.mako.font = with cfg.monospace; "${family} ${size}";

    home.packages = builtins.map (profile: profile.package) (with cfg; [
      monospace
      regular
      emoji
    ]);
  };
}
