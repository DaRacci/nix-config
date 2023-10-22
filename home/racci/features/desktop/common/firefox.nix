{ pkgs, config, ... }: {
  programs.firefox = {
    enable = true;
    package = pkgs.unstable.wrapFirefox pkgs.unstable.firefox-beta-unwrapped {
      cfg = {
        enableGnomeExtensions = true;
      };
    };

    profiles.racci = {
      extensions = with config.nur.repos.rycee.firefox-addons; [
        # Privacy / Security
        decentraleyes
        ublock-origin
        clearurls

        # Single Site Improvements
        augmented-steam
        enhancer-for-youtube

        # Misc
        i-dont-care-about-cookies
        search-by-image
        onepassword-password-manager
        darkreader
        sidebery
      ];

      search = {
        default = "Google";
        force = true;
        order = [ "Google" "Nix Packages" "Nix Options" "NixOS Wiki" "Home Manager Options" "Proton DB" ];
        engines =
          let
            searchNixURL = "https://search.nixos.org/";
            searchNixIcon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          in
          {
            "Nix Packages" = {
              urls = [{ template = "${searchNixURL}packages?type=packages&query={searchTerms}"; }];
              icon = searchNixIcon;
              definedAliases = [ "@np" ];
            };

            "Nix Options" = {
              urls = [{ template = "${searchNixURL}options?query={searchTerms}"; }];
              icon = searchNixIcon;
              definedAliases = [ "@no" ];
            };

            "NixOS Wiki" = {
              urls = [{ template = "https://nixos.wiki/index.php?search={searchTerms}"; }];
              iconUpdateURL = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = [ "@nw" ];
            };

            "Home Manager Options" = {
              urls = [{ template = "https://mipmip.github.io/home-manager-option-search/?query={searchTerms}"; }];
              icon = searchNixIcon;
              definedAliases = [ "@hmo" ];
            };

            "Proton DB" = {
              urls = [{ template = "https://www.protondb.com/search?q={searchTerms}"; }];
              iconUpdateURL = "https://www.protondb.com/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = [ "@pdb" ];
            };

            "Google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
          };
      };

      settings = {
        # TODO - Remove once homepage is changed
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.topSitesRows" = 2;

        # UI
        "browser.toolsbars.bookmarks.visibility" = "never";

        # Hardening / Security
        "dom.security.https_only_mode" = true;
        "privacy.donottrackheader.enabled" = true;
        "privacy.trackingprotection.enabled" = true;

        # Disable default browser check
        "browser.shell.checkDefaultBrowser" = false;

        # Disable built in account saving
        "signon.rememberSignons" = false;

        # Disable Sending data to Mozilla
        "datareporting.healthreport.uploadEnabled" = false;
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
        ".mozilla/firefox/racci/bookmarkbackups" # Bookmarks
      ];
      files = let dir = ".mozilla/firefox/racci"; in [
        # Bookmarks
        ".mozilla/firefox/racci/places.sqlite" # Bookmarks // TODO -> Mozilla Sync
        ".mozilla/firefox/racci/favicons.sqlite" # Favicons for bookmarks // TODO -> Needed?
        # Site Specific
        ".mozilla/firefox/racci/permissions.sqlite" # Permissions
        ".mozilla/firefox/racci/content-prefs.sqlite" # Permissions
        ".mozilla/firefox/racci/cookies.sqlite" # Offline Storage
        ".mozilla/firefox/racci/webappsstore.sqlite" # Offline Storage
        ".mozilla/firefox/racci/chromeappstore.sqlite" # Offline Storage
        # Persistent Information
        ".mozilla/firefox/racci/sessionstore.jsonlz4" # Session restore
        "${dir}/signedInUser.json" # Mozilla Sync
        "${dir}/containers.json" # Containers

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
