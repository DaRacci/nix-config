{
  config,
  lib,
  ...
}:
{
  sops.secrets = {
    SEARXNG_ENVIRONMENT = {
      owner = config.users.users."searx".name;
      group = config.users.groups."searx".name;
    };
  };

  services = {
    # TODO - Add fallback ollama for when nixe is down
    open-webui = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
      environment = {
        OLLAMA_BASE_URLS = "http://nixe:11434";

        PDF_EXTRACT_IMAGES = "true";
        ENABLE_RAG_LOCAL_WEB_FETCH = "true";
        RAG_EMBEDDING_MODEL_AUTO_UPDATE = "true";
        RAG_RERANKING_MODEL_AUTO_UPDATE = "true";

        ENABLE_RAG_WEB_SEARCH = "true";
        ENABLE_SEARCH_QUERY = "true";
        RAG_WEB_SEARCH_ENGINE = "searxng";
        SEARXNG_QUERY_URL = "http://localhost:9000/search?q=<query>";

        AUDIO_STT_MODEL = "whisper-1";
        WHISPER_MODEL = "base";
        WHISPER_MODEL_AUTO_UPDATE = "true";
      };
    };

    searx = {
      enable = true;
      redisCreateLocally = true;

      limiterSettings = {
        botdetection.ip_limit.link_token = false;
        botdetection.ip_lists = {
          block_ip = [ ];
          pass_ip = [ ];
        };
      };

      settings = {
        useDefaultSettings = true;
        general = {
          debug = false;
          instance_name = "SearXNG";
          privacy_policy_url = false;
          contact_url = false;
        };

        server = {
          port = 8888;
          bind_address = "0.0.0.0";
          base_url = "https://search.racci.dev";
          secret_key = "@SECRET_KEY@";
          public_instance = false;

          method = "POST";
          default_http_headers = {
            X-Content-Type-Options = "nosniff";
            X-Download-Options = "noopen";
            X-Robots-Tag = "noindex, nofollow";
            Referrer-Policy = "no-referrer";
          };
        };

        search = {
          safe_search = 0;
          autocomplete = "";
          autocomplete_min = 4;
          # favicon_resolver = "duckduckgo";
          default_lang = "auto";
          ban_time_on_fail = 5;
          max_ban_time_on_fail = 120;
          prefer_configured_language = true;
          formats = [
            "html"
            "json"
            "csv"
            "rss"
          ];
        };

        ui = {
          infinite_scroll = true;
          query_in_title = true;
          center_alignment = true;
          default_theme = "simple";
          theme_args = {
            simple_style = "auto";
          };
          search_on_category_select = true;
          hotkeys = "default";
          url_formatting = "pretty";
          static_use_hash = true;
        };

        outgoing = {
          request_timeout = 2.0;
          max_request_timeout = 10.0;
          pool_connections = 100;
          pool_maxsize = 20;
        };

        enabled_plugins = [
          "Basic Calculator"
          "Hash plugin"
          "Self Information"
          "Tracker URL remover"
          "Unit converter plugin"
          "Ahmia blacklist"
          "Hostnames plugin"
        ];

        hostnames = {
          replace = {
            "(.*\.)\.fandom\.com$" = "https://breezewiki.catsarch.com/$1/";
          };
          remove = [
            "(.*\.)?facebook.com$"
          ];
          high_priority = [
            "(.*\.)?wikipedia.org$"
          ];
        };

        categories_as_tabs = {
          general = { };
          images = { };
          videos = { };
          news = { };
          map = { };
          music = { };
          it = { };
          science = { };
          files = { };
          "social media" = { };
          utilities = { };
          shopping = { };
          "software wikis" = { };
        };

        engines =
          lib.mapAttrsToList
            (
              name: value:
              value
              // {
                inherit name;
                disabled = value.disabled or false;
              }
            )
            (
              {
                #region Web Search
                "bing" = {
                  engine = "bing";
                  shortcut = "bi";
                  categories = [ "general" ];
                };
                "duckduckgo" = {
                  engine = "duckduckgo";
                  shortcut = "ddg";
                  categories = [ "general" ];
                };
                "google" = {
                  engine = "google";
                  shortcut = "go";
                  categories = "general";
                  use_mobile_ui = false;
                };
                "brave" = {
                  engine = "brave";
                  shortcut = "br";
                  timeRangeSupport = true;
                  paging = true;
                  categories = [
                    "general"
                    "web"
                  ];
                  braveCategory = "search";
                };
                #endregion

                #region Image Sea;rch
                "bing images" = {
                  engine = "bing_images";
                  shortcut = "bii";
                  categories = [ "images" ];
                };
                "duckduckgo images" = {
                  engine = "duckduckgo_extra";
                  shortcut = "ddgi";
                  categories = [
                    "images"
                    "web"
                  ];
                  ddg_category = "images";
                };
                "tineye" = {
                  engine = "tineye";
                  shortcut = "tin";
                  categories = [ "images" ];
                  paging = true;
                  timeout = 9.0;
                };
                "google images" = {
                  engine = "google_images";
                  shortcut = "goi";
                  categories = [ "images" ];
                };
                "material icons" = {
                  engine = "material_icons";
                  categories = [ "images" ];
                  shortcut = "mi";
                };
                "brave.images" = {
                  engine = "brave";
                  network = "brave";
                  shortcut = "brimg";
                  categories = [
                    "images"
                    "web"
                  ];
                  braveCategory = "images";
                };
                #endregion

                #region Video Search
                "bing videos" = {
                  engine = "bing_videos";
                  shortcut = "biv";
                  categories = [
                    "videos"
                    "web"
                  ];
                };
                "duckduckgo videos" = {
                  engine = "duckduckgo_extra";
                  shortcut = "ddv";
                  categories = [
                    "videos"
                    "web"
                  ];
                  ddg_category = "videos";
                };
                "google videos" = {
                  engine = "google_videos";
                  shortcut = "gov";
                  categories = [
                    "videos"
                    "web"
                  ];
                };
                "youtube" = {
                  engine = "youtube_noapi";
                  shortcute = "yt";
                  categories = [ "videos" ];
                };
                "brave.videos" = {
                  engine = "brave";
                  network = "brave";
                  shortcut = "brvid";
                  categories = [
                    "videos"
                    "web"
                  ];
                  braveCategory = "videos";
                };
                #endregion

                #region News Search
                "bing news" = {
                  engine = "bing_news";
                  shortcut = "bin";
                  categories = [ "news" ];
                };
                "duckduckgo news" = {
                  engine = "duckduckgo_extra";
                  categories = [
                    "news"
                    "web"
                  ];
                  ddg_category = "news";
                  shortcut = "ddn";
                };
                "google news" = {
                  engine = "google_news";
                  shortcut = "gon";
                  categories = [ "news" ];
                };
                "hackernews" = {
                  engine = "hackernews";
                  shortcut = "hn";
                  categories = [
                    "it"
                    "news"
                  ];
                };
                "brave.news" = {
                  engine = "brave";
                  network = "brave";
                  shortcut = "brnews";
                  categories = [ "news" ];
                  braveCategory = "news";
                };
                #endregion

                #region Utilities
                "currency" = {
                  engine = "currency_convert";
                  shortcut = "cc";
                  categories = [ "utilities" ];
                };
                "duckduckgo weather" = {
                  engine = "duckduckgo_weather";
                  shortcut = "ddw";
                  categories = [ "utilities" ];
                };
                "duckduckgo definitions" = {
                  engine = "duckduckgo_definitions";
                  # shortcut = "ddd";
                  weight = 2.0;
                  categories = [ "utilities" ];
                };
                "urbandictionary" = {
                  engine = "xpath";
                  search_url = "https://www.urbandictionary.com/define.php?term={query}";
                  url_xpath = "//*[@class=\"word\"]/@href";
                  title_xpath = "//*[@class=\"def-header\"]";
                  content_xpath = "//*[@class=\"meaning\"]";
                  shortcut = "ud";
                  categories = [ "utilities" ];
                };
                "libretranslate" = {
                  engine = "libretranslate";
                  base_url = "https://libretranslate.com/translate";
                  shortcut = "lt";
                  categories = [
                    "utilities"
                    "translate"
                  ];
                };
                #endregion

                #region Shopping
                "ebay" = {
                  engine = "ebay";
                  shortcut = "eb";
                  base_url = "https://www.ebay.com";
                  categories = [ "shopping" ];
                  timeout = 5;
                };
                #endregion

                #region Science
                "google scholar" = {
                  engine = "google_scholar";
                  shortcut = "gos";
                  categories = [ "science" ];
                };
                #endregion

                #region Maps
                "openstreetmap" = {
                  engine = "openstreetmap";
                  shortcut = "osm";
                  categories = [ "map" ];
                };
                #endregion

                #region Music
                "spotify" = {
                  engine = "spotify";
                  shortcut = "sft";
                  categories = [ "music" ];
                  api_client_id = "@SPOTIFY_CLIENT_ID";
                  api_client_secret = "@SPOTIFY_CLIENT_SECRET";
                };
                #endregion

                #region App Search Engines
                "apk mirror" = {
                  engine = "apkmirror";
                  timeout = 4.0;
                  shortcut = "apkm";
                  categories = [
                    "it"
                    "apps"
                  ];
                };
                "apple app store" = {
                  engine = "apple_app_store";
                  shortcut = "aps";
                  categories = [
                    "it"
                    "apps"
                  ];
                };
                "google play apps" = {
                  engine = "google_play";
                  categories = [
                    "it"
                    "apps"
                  ];
                  shortcut = "gpa";
                  play_categ = "apps";
                };
                #endregion

                #region Package Search Engines
                "alpine linux packages" = {
                  engine = "alpinelinux";
                  shortcut = "alp";
                  categories = [
                    "it"
                    "packages"
                  ];
                };
                "docker hub" = {
                  engine = "docker_hub";
                  shortcut = "dh";
                  categories = [
                    "it"
                    "packages"
                  ];
                };
                "crates.io" = {
                  engine = "crates";
                  shortcut = "crates";
                };
                "lib.rs" = {
                  engine = "lib_rs";
                  shortcut = "lrs";
                };
                #endregion

                #region Wikis;
                "arch linux wiki" = {
                  engine = "archlinux";
                  shortcut = "alw";
                  categories = [
                    "it"
                    "software wikis"
                  ];
                };
                "nixos wiki" = {
                  engine = "mediawiki";
                  base_url = "https://wiki.nixos.org/";
                  search_type = "text";
                  shortcut = "nw";
                  categories = [
                    "it"
                    "software wikis"
                  ];
                };
                "wikipedia" = {
                  engine = "wikipedia";
                  shortcut = "wp";
                  base_url = "https://{language}.wikipedia.org/";
                  categories = [ "general" ];
                  display_type = [ "infobox" ];
                };
                "free software directory" = {
                  engine = "mediawiki";
                  shortcut = "fsd";
                  categories = [
                    "it"
                    "software wikis"
                  ];
                  base_url = "https://directory.fsf.org/";
                  search_type = "title";
                  timeout = 5.0;
                  about = {
                    website = "https://directory.fsf.org/";
                    wikidata_id = "Q2470288";
                  };
                };
                "wikidata" = {
                  engine = "wikidata";
                  shortcut = "wd";
                  categories = [ "general" ];
                  display_type = [ "infobox" ];
                  timeout = 3.0;
                  weight = 2.0;
                };
                #endregion

                #region Software Repositories
                "bitbucket" = {
                  engine = "xpath";
                  paging = true;
                  searchUrl = "https://bitbucket.org/repo/all/{pageno}?name={query}";
                  urlXpath = "//article[@class=\"repo-summary\"]//a[@class=\"repo-link\"]/@href";
                  titleXpath = "//article[@class=\"repo-summary\"]//a[@class=\"repo-link\"]";
                  contentXpath = "//article[@class=\"repo-summary\"]/p";
                  categories = [
                    "it"
                    "repos"
                  ];
                  timeout = 4.0;
                };
                "gitlab" = {
                  engine = "gitlab";
                  base_url = "https://gitlab.com";
                  shortcut = "gl";
                  categories = [
                    "it"
                    "repos"
                  ];
                  about = {
                    website = "https://gitlab.com";
                    wikidata_id = "Q16639197";
                  };
                };
                "github" = {
                  engine = "github";
                  shortcut = "gh";
                  categories = [
                    "it"
                    "repos"
                  ];
                };
                #endregion

                #region Social Media
                "reddit" = {
                  engine = "reddit";
                  shortcut = "re";
                  categories = [ "social media" ];
                  page_size = 25;
                  timeout = 10.0;
                };
                #endregion

                #region Q&A
                "stackoverflow" = {
                  engine = "stackexchange";
                  shortcut = "so";
                  api_site = "stackoverflow";
                  categories = [
                    "it"
                    "q&a"
                  ];
                };
                "superuser" = {
                  engine = "stackexchange";
                  shortcut = "su";
                  api_site = "superuser";
                  categories = [
                    "it"
                    "q&a"
                  ];
                };
                #endregion

                #region Disabled Engines
              }
              // (lib.genAttrs
                [
                  "bt4g"
                  "kickass"
                  "piratebay"
                  "solidtorrents"
                  "wikicommans.files"
                  "z-library"
                ]
                (_engine: {
                  disabled = true;
                })
              )
            );

        locales = {
          en = "English";
          ar = "العَرَبِيَّة (Arabic)";
          bg = "Български (Bulgarian)";
          bo = "བོད་སྐད་ (Tibetian)";
          ca = "Català (Catalan)";
          cs = "Čeština (Czech)";
          cy = "Cymraeg (Welsh)";
          da = "Dansk (Danish)";
          de = "Deutsch (German)";
          el_GR = "Ελληνικά (Greek_Greece)";
          eo = "Esperanto (Esperanto)";
          es = "Español (Spanish)";
          et = "Eesti (Estonian)";
          eu = "Euskara (Basque)";
          fa_IR = "(فārsī) فارسى (Persian)";
          fi = "Suomi (Finnish)";
          fil = "Wikang Filipino (Filipino)";
          fr = "Français (French)";
          gl = "Galego (Galician)";
          he = "עברית (Hebrew)";
          hr = "Hrvatski (Croatian)";
          hu = "Magyar (Hungarian)";
          ia = "Interlingua (Interlingua)";
          it = "Italiano (Italian)";
          ja = "日本語 (Japanese)";
          lt = "Lietuvių (Lithuanian)";
          nl = "Nederlands (Dutch)";
          nl_BE = "Vlaams (Dutch_Belgium)";
          oc = "Lenga D'òc (Occitan)";
          pl = "Polski (Polish)";
          pt = "Português (Portuguese)";
          pt_BR = "Português (Portuguese_Brazil)";
          ro = "Română (Romanian)";
          ru = "Русский (Russian)";
          sk = "Slovenčina (Slovak)";
          sl = "Slovenski (Slovene)";
          sr = "српски (Serbian)";
          sv = "Svenska (Swedish)";
          te = "(తెలుగు) telugu";
          ta = "(தமிழ்) Tamil";
          tr = "Türkçe (Turkish)";
          uk = "українська мова (Ukrainian)";
          vi = "tiếng Việt (Vietnamese)";
          zh = "(Chinese)";
          zh_TW = "(國語 ) Taiwanese Mandarin";
        };

        doi_resolvers = {
          "oadoi.org" = "https://oadoi.org/";
          "doi.org" = "https://doi.org/";
          "doai.io" = "https://dissem.in/";
          "sci-hub.se" = "https://sci-hub.se/";
          "sci-hub.do" = "https://sci-hub.do/";
          "scihubtw.tw" = "https://scihubtw.tw/";
          "sci-hub.st" = "https://sci-hub.st/";
          "sci-hub.bar" = "https://sci-hub.bar/";
          "sci-hub.it.nf" = "https://sci-hub.it.nf";
        };

        defaultDoiResolver = "oadoi.org";
      };
      environmentFile = config.sops.secrets.SEARXNG_ENVIRONMENT.path;
    };

    caddy.virtualHosts = {
      "ai".extraConfig = ''
        reverse_proxy http://${config.services.open-webui.host}:${toString config.services.open-webui.port}
      '';
      "search".extraConfig = ''
        reverse_proxy http://${config.services.searx.settings.server.bind_address}:${toString config.services.searx.settings.server.port}
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ config.services.searx.settings.server.port ];
}
