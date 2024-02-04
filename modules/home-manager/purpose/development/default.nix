{ lib, pkgs, config, ... }: with lib; let
  cfg = config.purposes.development;

  packages = with pkgs; [ ]
    ++ (optional cfg.enableGameDevelopment [ godot ])
    ++ (optional cfg.languages.rust [ unstable.jetbrains.rust-rover ])
    ++ (optional cfg.languages.jvm [ jetbrains.intellij-idea-community ]);
in
{
  options.purposes.development = {
    enable = mkEnableOption "development";

    enableGameDevelopment = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable development support for game development.
      '';
    };

    languages = mkOption {
      type = with types; types.listOf (types.enum [ "rust" "jvm" "powershell" ]);
      default = [ ];
      description = ''
        The languages to enable development support for.
      '';
    };
  };

  config = mkIf cfg.enable {
    home = {
      inherit packages;
    };


  };
}
