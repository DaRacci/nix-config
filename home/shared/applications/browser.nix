{ inputs, config, pkgs, lib, ... }: with lib; let
  mkLockedValue = value: {
    Value = value;
    Status = "locked";
  };
  mkLockedAttr = value: value // { Status = "locked"; };
  lock-false = mkLockedValue false;
  lock-true = mkLockedValue true;

  mkExtension = shortId: guid: args: nameValuePair guid ({
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${shortId}/latest.xpi";
    installation_mode = "force_installed";
  } // args);
  mkSimpleExtension = shortId: guid: mkExtension shortId guid { };
in
{
  home = {
    sessionVariables.BROWSER = lib.mkForce "firefox";

    file."firefox-gnome-theme" = {
      target = ".mozilla/firefox/${config.home.username}/chrome/firefox-gnome-theme";
      source = inputs.firefox-gnome-theme;
    };
  };

  programs.firefox = {
    enable = true;
    package = pkgs.unstable.firefox;

    /* ---- POLICIES
    * Check about:policies#documentation for options. */
    policies =
      let
        Extensions = trivial.pipe [
          # Privacy / Security
          [ "ublock-origin" "uBlock0@raymondhill.net" ]
          [ "istilldontcareaboutcookies" "idcac-pub@guus.ninja" ]
          [ "clearurls" "{74145f27-f039-47ce-a470-a662b129930a}" ]

          # Essentials
          [ "darkreader" "addon@darkreader.org" ]
          [ "sidebery" "{3c078156-979c-498b-8990-85f7987dd929}" ]
          [ "1password-x-password-manager" "{d634138d-c276-4fc8-924b-40a0ea21d284}" ]

          # Site Improvements
          [ "enhancer-for-youtube" "enhancerforyoutube@maximerf.addons.mozilla.org" ]
          [ "augmented-steam" "{1be309c5-3e4f-4b99-927d-bb500eb4fa88}" ]
          [ "search_by_image" "{2e5ff8c8-32fe-46d0-9fc8-6b8986621f3c}" ]
        ] [
          (map (arr: { id = elemAt arr 1; name = elemAt arr 0; }))
          (map (ext: nameValuePair ext.name { inherit (ext) id name; }))
          listToAttrs
        ];
      in
      {
        # Privacy
        DisableAccounts = true;
        DisableFeedbackCommands = true;
        DisableFirefoxAccounts = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DontCheckDefaultBrowser = true;
        FirefoxHome = mkLockedAttr {
          Search = true;
          TopSites = false;
          SponsoredTopSites = false;
          Highlights = false;
          Pocket = false;
          SponsoredPocket = false;
          Snippets = false;
        };
        FirefoxSuggest = mkLockedAttr {
          WebSuggestions = false;
          SponsoredSuggestions = false;
          ImproveSuggestions = false;
        };
        EnableTrackingProtection = mkLockedAttr {
          Cryptomining = true;
          Fingerprinting = true;
          EmailTracking = true;
        };

        # Annoyances
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        UserMessaging = mkLockedAttr {
          WhatsNew = false;
          ExtensionRecommendations = false;
          FeatureRecommendations = false;
          SkipOnBoarding = true;
          MoreFromMozilla = false;
        };

        /* ---- EXTENSIONS
        * Check about:debugging#/runtime/this-firefox for extension/add-on ID strings. */
        ExtensionSettings = (listToAttrs (mapAttrsToList (n: v: mkSimpleExtension n v.id) Extensions)) // {
          # "*" = {
        };

        "3rdparty".Extensions =
          let
            allowPrivateBrowsing = ext: nameValuePair ext.id {
              permissions = [ "internal:privateBrowsingAllowed" ];
            };
          in
          pkgs.lib.mine.attrsets.recursiveMergeAttrs [
            (trivial.pipe [
              Extensions.ublock-origin
              Extensions.istilldontcareaboutcookies
              Extensions.clearurls

              Extensions.darkreader
              Extensions."1password-x-password-manager"
            ] [
              (map allowPrivateBrowsing)
              listToAttrs
            ])
            {
              "${Extensions.ublock-origin.id}" = {
                userSettings = [ ];
                advancedSettings = [ ];
                toOverwrite = {
                  filterLists = [
                    "user-filters"

                    "ublock-filters"
                    "ublock-badware"
                    "ublock-privacy"
                    "ublock-unbreak"
                    "ublock-quick-fixes"
                    "adguard-generic"
                    "adgaurd-mobile"
                    "easylist"

                    "adguard-spyware-url"
                    "adguard-spyware"
                    "block-lan"
                    "easyprivacy"

                    "urlhaus-1"
                    "curben-phishing"

                    "adguard-social"
                    "adguard-cookies"
                    "ublock-cookies-adguard"
                    "adguard-popup-overlays"
                    "adguard-mobile-app-banners"
                    "adguard-other-annoyances"
                    "adguard-widgets"
                    "fanboy-thirdparty_social"
                    "easylist-annoyances"
                    "easylist-chat"
                    "fanboy-cookiemonster"
                    "ublock-cookies-easylist"
                    "easylist-newsletters"
                    "easylist-notifications"
                    "fanboy-social"
                    "ublock-annoyances"

                    "dpollock-0"
                    "plowe-0"
                  ];
                };

                toAdd = {
                  rules = [
                    "* * 3p-frame block"
                  ];
                };
              };
            }

          ];

        /* ---- PREFERENCES
        * Set preferences shared by all profiles. */
        Preferences = {
          # Privacy
          "browser.topsites.contile.enabled" = lock-false;
          "browser.formfill.enable" = lock-false;
          "browser.search.suggest.enabled" = lock-false;
          "browser.search.suggest.enabled.private" = lock-false;
          "browser.urlbar.suggest.searches" = lock-false;
          "browser.urlbar.showSearchSuggestionsFirst" = lock-false;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = lock-false;
          "browser.newtabpage.activity-stream.feeds.snippets" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lock-false;
          "browser.newtabpage.activity-stream.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.system.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock-false;

          /* ---- GEOLOCATION
          * Use Mozilla's geolocation service instead of Google's.
          * Disable using the OS's geolocation service. */
          "geo.provider.network.url" = mkLockedValue "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%";
          "geo.provider.network.logging.enabled" = lock-true;
          "geo.provider.ms-windows-location" = lock-false;
          "geo.provider.use_corelocation" = lock-false;
          "geo.provider.use_gpsd" = lock-false;
          "geo.provider.use_geoclue" = lock-false;

          /* ---- TELEMETRY
          * Disable telemetry and data collection. */
          "toolkit.telemetry.unified" = lock-false;
          "toolkit.telemetry.enabled" = lock-false;
          "toolkit.telemetry.server" = lock-false;
          "toolkit.telemetry.archive.enabled" = mkLockedValue "data:,";
          "toolkit.telemetry.newProfilePing.enabled" = lock-false;
          "toolkit.telemetry.shutdownPingSender.enabled" = lock-false;
          "toolkit.telemetry.updatePing.enabled" = lock-false;
          "toolkit.telemetry.bhrPing.enabled" = lock-false;
          "toolkit.telemetry.firstShutdownPing.enabled" = lock-false;
        };
      };

    profiles.${config.home.username} = {
      containers = {
        Personal = {
          id = 1;
          icon = "fingerprint";
          color = "purple";
        };
        Work = {
          id = 2;
          icon = "briefcase";
          color = "yellow";
        };
        Entertainment = {
          id = 3;
          icon = "chill";
          color = "blue";
        };
        Shopping = {
          id = 4;
          icon = "cart";
          color = "green";
        };
        Banking = {
          id = 5;
          icon = "dollar";
          color = "turquoise";
        };
      };

      settings = {
        "browser.tabs.loadInBackground" = true;
        "widget.gtk.rounded-bottom-corners.enabled" = true;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "svg.context-properties.content.enabled" = true;
        "gnomeTheme.hideSingleTab" = true;
        "gnomeTheme.bookmarksToolbarUnderTabs" = true;
        "gnomeTheme.normalWidthTabs" = false;
        "gnomeTheme.tabsAsHeaderbar" = true;
      };

      userChrome = ''
        @import "firefox-gnome-theme/userChrome.css";
      '';
      userContent = ''
        @import "firefox-gnome-theme/userContent.css";
      '';

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
              urls = [{ template = "https://home-manager-options.extranix.com/?query={searchTerms}"; }];
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
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = lib.mkForce [ "firefox.desktop" ];
    "text/xml" = lib.mkForce [ "firefox.desktop" ];
    "x-scheme-handler/http" = lib.mkForce [ "firefox.desktop" ];
    "x-scheme-handler/https" = lib.mkForce [ "firefox.desktop" ];
  };

  # For information about what the folders are for, see:
  # https://support.mozilla.org/en-US/kb/profiles-where-firefox-stores-user-data
  user.persistence =
    let
      profiles = attrNames config.programs.firefox.profiles;
      onEachProfile = value: map (profile: ".mozilla/firefox/${profile}/${value}") profiles;
    in
    {
      directories = trivial.pipe [
        "sessionstore-backups" # Session restore
        "bookmarkbackups" # Bookmarks
      ] [
        (map onEachProfile)
        flatten
      ];

      files = trivial.pipe [
        # Bookmarks
        "places.sqlite" # Bookmarks // TODO -> Mozilla Sync
        "favicons.sqlite" # Favicons for bookmarks // TODO -> Needed?
        # Site Specific
        "permissions.sqlite" # Permissions
        "content-prefs.sqlite" # Permissions
        "cookies.sqlite" # Offline Storage
        "webappsstore.sqlite" # Offline Storage
        "chromeappstore.sqlite" # Offline Storage
        # Persistent Information
        "sessionstore.jsonlz4" # Session restore
        "signedInUser.json" # Mozilla Sync
      ] [
        (map onEachProfile)
        flatten
      ];
    };
}
