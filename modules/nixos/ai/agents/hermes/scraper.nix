{
  config,
  inputs,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optional
    types
    ;
  inherit (types) nullOr str;

  cfg = config.services.ai-agent;
in
{
  imports = optional importExternals inputs.trafilatura-scrape.nixosModules.default;

  options.services.ai-agent.extras.scraper = {
    enable = mkEnableOption "web scraping and search plugins for the agent";
    searxEndpoint = mkOption {
      type = nullOr str;
      default = null;
      description = "The SearxNG endpoint to use for web search.";
    };
  };

  config = mkIf (cfg.enable && cfg.extras.scraper.enable) {
    services = {
      trafilatura-scrape = {
        enable = true;
        searxng.url = cfg.extras.scraper.searxEndpoint;
      };

      ai-agent.settings = {
        plugins.enabled = [
          "web-searxng"
          "web-firecrawl"
        ];
        web = {
          search_backend = "searxng";
          extract_backend = "firecrawl";
        };
      };

      hermes-agent = {
        extraDependencyGroups = [ "firecrawl" ];
        environment = {
          FIRECRAWL_API_URL = "http://127.0.0.1:${toString config.services.trafilatura-scrape.port}";
          SEARXNG_URL = cfg.extras.scraper.searxEndpoint;
        };
      };
    };
  };
}
