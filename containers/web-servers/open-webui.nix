# Based on https://github.com/open-webui/open-webui/blob/main/docker-compose.yaml
_: {
  project.name = "open-webui";

  services = {
    open-webui = {
      service = {
        image = "ghcr.io/open-webui/open-webui:main";
        environment = {
          OLLAMA_BASE_URL = "http://localhost:11434";
          ENABLE_RAG_WEB_SEARCH = "true";
          RAG_WEB_SEARCH_ENGINE = "searxng";
          RAG_WEB_SEARCH_RESULT_COUNT = 3;
          RAG_WEB_SEARCH_CONCURRENT_REQUESTS = 10;
          SEARXNG_QUERY_URL = "http://searxng:8080/search?q=<query>";
        };

        volumes = [
          "open-webui:/app/backend/data"
        ];

        network_mode = "host";
        # ports = [ "3000:8080" ];
        # extra_hosts = [ "host.docker.internal:host-gateway" ];
        restart = "unless-stopped";
        depends_on = [ "searxng" ];
      };
    };

    searxng = {
      service = {
        image = "searxng/searxng:latest";
        # ports = [ "8080" ];
        volumes = [ "searxng:/etc/searxng" ];
        restart = "always";
      };
    };
  };

  docker-compose.volumes = {
    open-webui = { };
    searxng = { };
  };
}
