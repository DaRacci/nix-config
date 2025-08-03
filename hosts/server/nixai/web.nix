{
  config,
  lib,
  ...
}:
{
  sops =
    let
      db = config.server.database.postgres.open_webui;
      placeholder = config.sops.placeholder;
    in
    {
      templates.openweb-ui-env.content = lib.toShellVars {
        DATABASE_URL = "postgresql://${db.user}:${
          placeholder."POSTGRES/OPEN_WEBUI_PASSWORD"
        }@${db.host}/${db.database}";
      };
    };

  services = {
    open-webui = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;

      environmentFile = config.sops.templates.openweb-ui-env.path;
      environment = {
        WEBUI_URL = "https://ai.racci.dev";

        # User Settings
        # ENABLE_SIGNUP = "false";

        # Features
        ENABLE_CHANNELS = "false";

        # Tasks
        TASK_MODEL = "qwen3:1.7b";
        ENABLE_TITLE_GENERATION = "true";
        ENABLE_FOLLOW_UP_GENERATION = "true";
        ENABLE_AUTOCOMPLETE_GENERATION = "true";
        ENABLE_TAGS_GENERATION = "true";

        # Connections
        ENABLE_OLLAMA_API = "true";
        OLLAMA_BASE_URLS = "http://nixmi:11434;http://localhost:11434";
        ENABLE_OPENAI_API = "false";

        # ??
        ENABLE_REALTIME_CHAT_SAVE = "true";
        ENABLE_VERSION_UPDATE_CHECK = "false";

        PDF_EXTRACT_IMAGES = "true";
        ENABLE_RAG_LOCAL_WEB_FETCH = "true";
        RAG_EMBEDDING_MODEL_AUTO_UPDATE = "true";
        RAG_RERANKING_MODEL_AUTO_UPDATE = "true";

        ENABLE_RAG_WEB_SEARCH = "true";
        ENABLE_SEARCH_QUERY = "true";
        RAG_WEB_SEARCH_ENGINE = "searxng";
        SEARXNG_QUERY_URL = "https://search.racci.dev/search?q=<query>";

        AUDIO_STT_MODEL = "whisper-1";
        WHISPER_MODEL = "base";
        WHISPER_MODEL_AUTO_UPDATE = "true";
      };
    };
  };

  server = {
    proxy.virtualHosts.ai =
      let
        cfg = config.services.open-webui;
      in
      {
        ports = [ cfg.port ];
        extraConfig = ''
          reverse_proxy http://${cfg.host}:${toString cfg.port}
        '';
      };

    database.postgres.open_webui = { };
  };
}
