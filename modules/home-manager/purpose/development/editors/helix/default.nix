{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;

  cfg = config.purpose.development.editors.helix;
  languages = config.purpose.development.languages;

  rendered = import ./render.nix {
    inherit lib languages;
  };
in
{
  options.purpose.development.editors.helix = {
    enable = mkEnableOption "Helix Editor";
  };

  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;
      extraPackages = [ pkgs.cmake-language-server ] ++ rendered.extraPackages;

      languages = rendered.languages;

      settings = {
        editor = {
          middle-click-paste = false;
          trim-final-newlines = true;
          trim-trailing-whitespace = true;

          end-of-line-diagnostics = "hint";

          lsp = {
            display-progress-messages = true;
            display-inlay-hints = true;
          };

          indent-guides.render = true;
          inline-diagnostics = {
            cursor-line = "hint";
            other-lines = "info";
          };
        };
      };
      ignores = [ ];
    };
  };
}
