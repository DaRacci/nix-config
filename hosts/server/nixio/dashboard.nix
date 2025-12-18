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
          theme = "adventure";
          defaultOpeningMethod = "workspace";
          faviconApi = "local";
          enableMultiTasking = true;
          preventWriteToDisk = true;
          disableUpdateChecks = true;

          webSearch = {
            searchEngine = "custom";
            customSearchEngine = "https://search.racci.dev/search?q=";
            openingMethod = "sametab";
            searchBangs = {
              np = "https://search.nixos.org/packages?type=packages&query=";
              no = "https://search.nixos.org/options?query=";
              nw = "https://nixos.wiki/index.php?search=";
            };
          };

          hideComponents = {
            hideHeading = true;
            hideFooter = true;
          };
        };

        pageInfo = {
          title = "Dashboard";
        };

        sections = [ ];
      };
    };
  };

  server = {
    dashboard.items.dashboard.icon = "sh-dashy";

    proxy.virtualHosts = {
      dashboard.extraConfig = ''
        header {
          X-Frame-Options SAMEORIGIN
          X-Robots-Tag "none"
        }

        root * ${config.services.dashy.finalDrv}
        file_server
      '';
    };
  };
}
