{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    ;
in
{
  options.core.locale = {
    enable = (mkEnableOption "locale configuration") // {
      default = true;
    };
  };

  config = mkIf config.core.locale.enable {
    time.timeZone = mkDefault "Australia/Sydney";

    i18n = {
      defaultLocale = mkDefault "en_AU.UTF-8";
      supportedLocales = mkDefault [
        "en_AU.UTF-8/UTF-8"
        "en_US.UTF-8/UTF-8"
      ];
    };
  };
}
