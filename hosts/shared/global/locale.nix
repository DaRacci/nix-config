{ pkgs, lib, ... }:
{
  i18n = {
    defaultLocale = "en_AU.UTF-8";

    supportedLocales = lib.mkDefault [
      "en_AU.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
  };

  services = {
    geoclue2 = {
      enable = true;
      enableWifi = true;
    };

    automatic-timezoned = {
      enable = false;
      package = pkgs.automatic-timezoned;
    };
  };

  location.provider = "geoclue2";
}
