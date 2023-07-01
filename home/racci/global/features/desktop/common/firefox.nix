{ pkgs, config, ... }: {
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;
    enableGnomeExtensions = true;

    profiles.racci = {
      extensions = with config.nur.repos.rycee.firefox-addons; [
        onepassword-password-manager
        ublock-origin
        darkreader
        sidebery
        augmented-steam
        i-dont-care-about-cookies
        clearurls
        enhancer-for-youtube
      ];

      search = {
        default = "Google";
        force = true;
        order = [ "Google" "Bing" "Nix Packages" "NixOS Wiki" ];
        engines = {
          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                { name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];

            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@np" ];
          };

          "NixOS Wiki" = {
            urls = [{ template = "https://nixos.wiki/index.php?search={searchTerms}"; }];
            iconUpdateURL = "https://nixos.wiki/favicon.png";
            updateInterval = 24 * 60 * 60 * 1000; # every day
            definedAliases = [ "@nw" ];
          };

          "Bing".metaData.hidden = true;
          "Google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
        };
      };

      settings = {
      };

      extraConfig = ''
      '';

      userChrome = ''
      '';

      userContent = ''
      '';
    };
  };

  home = {
    sessionVariables.BROWSER = "firefox";
    persistence."/persist/home/racci" = {
      # For information about what the folders are for, see:
      # https://support.mozilla.org/en-US/kb/profiles-where-firefox-stores-user-data

      directories = [
        ".mozilla/firefox/racci/sessionstore-backups" # Session restore
        ".mozilla/firefox/racci/bookmarkbackups"      # Bookmarks
      ];
      files = [
        # Bookmarks
        ".mozilla/firefox/racci/places.sqlite"          # Bookmarks // TODO -> Mozilla Sync
        ".mozilla/firefox/racci/favicons.sqlite"        # Favicons for bookmarks // TODO -> Needed?
        # Site Specific
        ".mozilla/firefox/racci/permissions.sqlite"     # Permissions
        ".mozilla/firefox/racci/content-prefs.sqlite"   # Permissions
        ".mozilla/firefox/racci/cookies.sqlite"         # Offline Storage
        ".mozilla/firefox/racci/webappsstore.sqlite"    # Offline Storage
        ".mozilla/firefox/racci/chromeappstore.sqlite"  # Offline Storage
        # Persistent Information
        ".mozilla/firefox/racci/sessionstore.jsonlz4"   # Session restore
        ".mozilla/firefox/racci/prefs.js"               # User preferences // TODO -> Needed?
        ".mozilla/firefox/racci/xulstore.json"          # Window size and position
        # Extension Specific
        ".mozilla/firefox/racci/extension-settings.json"
        ".mozilla/firefox/racci/extension-preferences.json"
        ".mozilla/firefox/racci/extensions.json"
      ];
    };
  };


  xdg.mimeApps.defaultApplications = {
    "text/html" = [ "firefox.desktop" ];
    "text/xml" = [ "firefox.desktop" ];
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
  };
}
