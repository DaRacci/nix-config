{
  config,
  ...
}:
{
  services = {
    dashy = {
      enable = true;
      # https://dashy.to/docs/configuring
      settings = {
        appConfig = {
          language = "en-AU";
          statusCheck = true;
          statusCheckInterval = 300;
          enableMultiTasking = true;
          showSplashScreen = true;
          disableUpdateChecks = true;

          # TODO - Maybe replace with the ai searx instance?
          webSearch = {
            searchEngine = "duckduckgo";
            openingMethod = "sametab";
            searchBangs = {
              np = "https://search.nixos.org/packages?type=packages&query=";
              no = "https://search.nixos.org/options?query=";
              nw = "https://nixos.wiki/index.php?search=";
            };
          };
        };

        pageInfo = {

        };

        sections = [ ];

        layout = {

        };
      };
    };
  };

  server.proxy.virtualHosts = {
    dashboard.extraConfig = ''
      header {
        X-Frame-Options SAMEORIGIN
        X-Robots-Tag "none"
      }

      root * ${config.services.dashy.finalDrv}
      file_server
    '';
  };
}
