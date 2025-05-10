{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  mkLockedValue = value: {
    Value = value;
    Status = "locked";
  };
  mkLockedAttr = value: value // { Status = "locked"; };
  lock-false = mkLockedValue false;
  lock-true = mkLockedValue true;

  mkExtension =
    shortId: guid: args:
    nameValuePair guid (
      {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/${shortId}/latest.xpi";
        installation_mode = "force_installed";
      }
      // args
    );
  mkSimpleExtension = shortId: guid: mkExtension shortId guid { };
in
{
  home = {
    sessionVariables.BROWSER = lib.mkForce "firefox";

    file."firefox-ultima" = {
      target = ".mozilla/firefox/${config.home.username}/chrome/firefox-ultima";
      source = inputs.firefox-ultima;
    };

    file."firefox-ultima-floorp" = {
      target = ".floorp/${config.home.username}/chrome/firefox-ultima";
      source = inputs.firefox-ultima;
    };
  };

  stylix = {
    targets = rec {
      firefox.profileNames = [ "racci" ];
      floorp.profileNames = firefox.profileNames;
    };
  };

  programs = rec {
    firefox = {
      enable = true;
      package = pkgs.firefox;

      languagePacks = [
        "en-GB"
        "en-US"
      ];

      /**
        ---- POLICIES
        Check about:policies#documentation for options.
      */
      policies =
        let
          /**
            ---- EXTENSIONS
            Check about:debugging#/runtime/this-firefox for extension/add-on ID strings.
            You can use about:policies to debug issues with extension installations.
          */
          Extensions =
            trivial.pipe
              [
                # Privacy / Security
                [
                  "ublock-origin"
                  "uBlock0@raymondhill.net"
                ]
                [
                  "istilldontcareaboutcookies"
                  "idcac-pub@guus.ninja"
                ]
                [
                  "clearurls"
                  "{74145f27-f039-47ce-a470-a662b129930a}"
                ]

                # Essentials
                [
                  "darkreader"
                  "addon@darkreader.org"
                ]
                [
                  "sidebery"
                  "{3c078156-979c-498b-8990-85f7987dd929}"
                ]
                [
                  "1password-x-password-manager"
                  "{d634138d-c276-4fc8-924b-40a0ea21d284}"
                ]
                [
                  "multi-account-containers"
                  "@testpilot-containers"
                ]
                [
                  "user-agent-string-switcher"
                  "{a6c4a591-f1b2-4f03-b3ff-767e5bedf4e7}"
                ]
                [
                  "violentmonkey"
                  "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}"
                ]

                # Site Improvements
                [
                  "enhancer-for-youtube"
                  "enhancerforyoutube@maximerf.addons.mozilla.org"
                ]
                [
                  "augmented-steam"
                  "{1be309c5-3e4f-4b99-927d-bb500eb4fa88}"
                ]
                [
                  "search_by_image"
                  "{2e5ff8c8-32fe-46d0-9fc8-6b8986621f3c}"
                ]
                [
                  "return-youtube-dislikes"
                  "{762f9885-5a13-4abd-9c77-433dcd38b8fd}"
                ]
                [
                  "indie-wiki-buddy"
                  "{cb31ec5d-c49a-4e5a-b240-16c767444f62}"
                ]
              ]
              [
                (map (arr: {
                  id = elemAt arr 1;
                  name = elemAt arr 0;
                }))
                (map (ext: nameValuePair ext.name { inherit (ext) id name; }))
                listToAttrs
              ];
        in
        {
          #region Privacy
          DisableAccounts = true;
          DisableFeedbackCommands = true;
          DisableFirefoxAccounts = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          DisableTelemetry = true;
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
          #endregion

          #region Annoyances
          DisableSetDesktopBackground = true;
          DisplayMenuBar = "default-off";
          DontCheckDefaultBrowser = true;
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
          #endregion

          #region Misc
          EncryptedMediaExtensions = mkLockedValue true;
          #endregion

          /**
            ---- EXTENSIONS
            Check about:debugging#/runtime/this-firefox for extension/add-on ID strings.
          */
          ExtensionSettings =
            let
              allowPrivateBrowsing =
                ext:
                nameValuePair ext.id {
                  permissions = [ "internal:privateBrowsingAllowed" ];
                };
            in
            pkgs.lib.mine.attrsets.recursiveMergeAttrs [
              (listToAttrs (mapAttrsToList (n: v: mkSimpleExtension n v.id) Extensions))
              (trivial.pipe
                [
                  Extensions.ublock-origin
                  Extensions.istilldontcareaboutcookies
                  Extensions.clearurls

                  Extensions.darkreader
                  Extensions."1password-x-password-manager"
                ]
                [ (map allowPrivateBrowsing) listToAttrs ]
              )
            ];

          "3rdparty".Extensions = {
            # Based on https://github.com/Kreyren/nixos-config/blob/bd4765eb802a0371de7291980ce999ccff59d619/nixos/users/kreyren/home/modules/web-browsers/firefox/firefox.nix#L116-L148
            "${Extensions.ublock-origin.id}" = {
              adminSettings = {
                userSettings = {
                  uiTheme = "dark";
                  uiAccentCustom = true;
                  uiAccentCustom0 = "#8300ff";
                  cloudStorageEnabled = false;
                  importedLists = [ ];
                  externalLists = [ ];
                };

                selectedFilterLists = [
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
            };
          };

          /**
            ---- PREFERENCES
            Set preferences shared by all profiles.
          */
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

            /**
              ---- GEOLOCATION
              Use Mozilla's geolocation service instead of Google's.
              Disable using the OS's geolocation service.
            */
            "geo.provider.network.url" =
              mkLockedValue "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%";
            "geo.provider.network.logging.enabled" = lock-true;
            "geo.provider.ms-windows-location" = lock-false;
            "geo.provider.use_corelocation" = lock-false;
            "geo.provider.use_gpsd" = lock-false;
            "geo.provider.use_geoclue" = lock-false;

            /**
              ---- TELEMETRY
              Disable telemetry and data collection.
            */
            "toolkit.telemetry.unified" = lock-false;
            "toolkit.telemetry.enabled" = lock-false;
            "toolkit.telemetry.server" = lock-false;
            "toolkit.telemetry.archive.enabled" = mkLockedValue "data:,";
            "toolkit.telemetry.newProfilePing.enabled" = lock-false;
            "toolkit.telemetry.shutdownPingSender.enabled" = lock-false;
            "toolkit.telemetry.updatePing.enabled" = lock-false;
            "toolkit.telemetry.bhrPing.enabled" = lock-false;
            "toolkit.telemetry.firstShutdownPing.enabled" = lock-false;

            # Misc stuff
            "browser.toolbars.bookmarks.visibility" = mkLockedValue "never";
          };
        };

      profiles.${config.home.username} = {
        containersForce = true;

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
          Admin = {
            id = 6;
            icon = "tree";
            color = "red";
          };
          Programming = {
            id = 7;
            icon = "circle";
            color = "pink";
          };
        };

        userChrome = ''
          @import "firefox-ultima/userChrome.css";
        '';
        userContent = ''
          @import "firefox-ultima/userContent.css";
        '';

        # We always want to load the user.js file because if its being updated, there are sometimes breaking changes that need it reapplied.
        # We then load our settings which will override the user.js defaults.
        extraConfig = ''
          ${builtins.readFile "${inputs.firefox-ultima}/user.js"}

          // This must be done manually so they are placed after the above user.js defaults.
          // Using the settings option will place them before the defaults.
          ${
            let
              # Copied from https://github.com/nix-community/home-manager/blob/2f23fa308a7c067e52dfcc30a0758f47043ec176/modules/programs/firefox.nix#L57-L61
              userPrefValue =
                pref:
                builtins.toJSON (if isBool pref || isInt pref || isString pref then pref else builtins.toJSON pref);

              settings = {
                "browser.tabs.loadInBackground" = true;
                "widget.gtk.rounded-bottom-corners.enabled" = true;
                "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
                "svg.context-properties.content.enabled" = true;
                "dom.event.clipboardevents.enabled" = true;

                # Ultima
                "ultima.OS.gnome" = true;
                "ultima.OS.gnome.wdl" = true;
                "ultima.OS.kde" = false;
                "ultima.disable.alltabs.button" = true;
                "ultima.disable.windowcontrols.button" = true;
                "ultima.disable.verticaltab.bar" = true;
                "ultima.disable.verticaltab.bar.withindicator" = false;
                "ultima.tabs.sidebery.autohide" = true;
                "ultima.tabs.vertical.hide" = true;
                "ultima.urlbar.hidebuttons" = true;
                "ultima.urlbar.centered" = true;
                "ultima.theme.extensions" = true;
                "ultima.theme.menubar" = true;
                "ultima.enable.js.config" = true;
              };
            in
            concatStrings (
              mapAttrsToList (name: value: ''
                user_pref("${name}", ${userPrefValue value});
              '') settings
            )
          }
        '';

        search = {
          default = "ddg";
          force = true;
          order = [
            "ddg"
            "Nix Packages"
            "Nix Options"
            "NixOS Wiki"
            "Home Manager Options"
            "Proton DB"
            "Wayback Machine"
          ];
          engines =
            let
              searchNixURL = "https://search.nixos.org/";
              searchNixIcon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            in
            {
              "Nix Packages" = {
                urls = [ { template = "${searchNixURL}packages?type=packages&query={searchTerms}"; } ];
                icon = searchNixIcon;
                definedAliases = [ "@np" ];
              };

              "Nix Options" = {
                urls = [ { template = "${searchNixURL}options?query={searchTerms}"; } ];
                icon = searchNixIcon;
                definedAliases = [ "@no" ];
              };

              "NixOS Wiki" = {
                urls = [ { template = "https://nixos.wiki/index.php?search={searchTerms}"; } ];
                icon = "https://nixos.wiki/favicon.png";
                updateInterval = 24 * 60 * 60 * 1000; # every day
                definedAliases = [ "@nw" ];
              };

              "Home Manager Options" = {
                urls = [ { template = "https://home-manager-options.extranix.com/?query={searchTerms}"; } ];
                icon = searchNixIcon;
                definedAliases = [ "@hmo" ];
              };

              "Proton DB" = {
                urls = [ { template = "https://www.protondb.com/search?q={searchTerms}"; } ];
                icon = "https://www.protondb.com/favicon.ico";
                updateInterval = 24 * 60 * 60 * 1000; # every day
                definedAliases = [ "@pdb" ];
              };

              "Github" = {
                urls = [
                  { template = "https://github.com/search?ref=opensearch&type=repositories&q={searchTerms}"; }
                ];
                icon = "https://github.githubassets.com/favicons/favicon.png";
                updateInterval = 24 * 60 * 60 * 1000;
                definedAliases = [ "@gh" ];
              };

              "Noogle" = {
                urls = [ { template = "https://noogle.dev/q?term={searchTerms}"; } ];
                icon = "https://noogle.dev/favicon.ico";
                updateInterval = 24 * 60 * 60 * 1000;
                definedAliases = [ "@noog" ];
              };

              "NixPkgsIssues" = {
                urls = [ { template = "https://github.com/NixOS/nixpkgs/issues?q={searchTerms}"; } ];
                icon = "https://nixos.org/logo/nixos-logo-only-hires.png";
                definedAliases = [ "@npi" ];
              };

              "Wayback Machine" = {
                urls = [ { template = "https://web.archive.org/web/*/{searchTerms}"; } ];
                icon = "https://archive.org/offshoot_assets/favicon.ico";
                definedAliases = [ "@wbm" ];
              };

              "google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
            };
        };
      };
    };

    floorp = {
      enable = true;
      inherit (firefox) languagePacks policies profiles;
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = [ "firefox.desktop" ];
    "text/xml" = [ "firefox.desktop" ];
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
  };

  # FIXME - This shouldn't be hard coded to my profile.
  # Has a infinite recursion if config is used to make the list.
  # user.persistence.directories = map (profile: ".mozilla/firefox/${profile}") (attrNames config.programs.firefox.profiles);
  user.persistence.directories = [
    ".mozilla/firefox/racci"
    ".floorp/racci"
  ];
}
