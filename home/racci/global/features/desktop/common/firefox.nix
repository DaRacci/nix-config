{ pkgs, lib, inputs, config, ... }:

let
  addons = inputs.firefox-addons.packages.${pkgs.system};
in {
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    profiles.racci = {
      extensions = with addons; [
        # onepassword-password-manager
        ublock-origin
        darkreader
        sidebery
        augmented-steam
        i-dont-care-about-cookies
        clearurls
        # enhancer-for-youtube
      ];
    };

    # settings = {

    # };

    # userChrome = ''
    # '';

    # userContent = ''
    # '';
  };

  home = {
    sessionVariables.BROWSER = "firefox";
    persistence = {
      "/persist/home/racci".directories = [ ".mozilla/firefox" ];
    };
  };


  xdg.mimeApps.defaultApplications = {
    "text/html" = [ "firefox.desktop" ];
    "text/xml" = [ "firefox.desktop" ];
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
  };
}
