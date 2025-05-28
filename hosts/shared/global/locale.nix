{
  lib,
  ...
}:
{
  i18n = {
    defaultLocale = "en_AU.UTF-8";

    supportedLocales = lib.mkDefault [
      "en_AU.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
  };
}
