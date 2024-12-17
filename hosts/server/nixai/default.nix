{ modulesPath, config, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  sops.secrets = {
    SEARXNG_SETTINGS = { };
  };

  services = {
    # TODO - Add fallback ollama for when nixe is down
    open-webui = {
      enable = true;
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
      settings = {
        server.port = 9000;
      };
      settingsFile = config.sops.secrets.SEARXNG_SETTINGS.path;
    };

    caddy.virtualHosts."ai".extraConfig = ''
      reverse_proxy ${config.services.open-webui.host}:${toString config.services.open-webui.port}
    '';
  };
}
