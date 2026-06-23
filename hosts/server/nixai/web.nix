{
  config,
  pkgs,
  lib,
  ...
}:
let
  db = config.server.database.postgres.open_webui;
  sopsPlaceholder = config.sops.placeholder;

in
{
  sops = {
    templates.openweb-ui-env.content = lib.toShellVars {
      DATABASE_URL = "postgresql://${db.user}:${
        sopsPlaceholder."POSTGRES/OPEN_WEBUI_PASSWORD"

      }@${db.host}/${db.database}";
    };
  };

  sops.secrets = {
    "REDIS/PASSWORD" = { };
    "FIRECRAWL/API_KEY" = { };
    "FIRECRAWL/BULL_AUTH_KEY" = { };
  };

  server = {
    database.postgres = {
      open_webui = { };
      firecrawl = { };
    };
    database.redis = {
      firecrawl = { };
      firecrawl-rate-limit = { };
    };
    database.dependentServices = [
      "open-webui"
      "firecrawl"
    ];
    dashboard.items.ai = {
      title = "Open WebUI";
      icon = "sh-open-webui";
    };

    proxy.virtualHosts = {
      ai =
        let
          cfg = config.services.open-webui;
        in
        {
          ports = [ cfg.port ];
          extraConfig = ''
            reverse_proxy http://${cfg.host}:${toString cfg.port} {
              flush_interval -1
            }
          '';
        };

      firecrawl = {
        ports = [ config.services.firecrawl.port ];
        public = true;
        kanidm = {
          allowGroups = [ "cloud@auth.racci.dev" ];
        };
        extraConfig = ''
          reverse_proxy http://${config.services.firecrawl.host}:${toString config.services.firecrawl.port}
        '';
      };
    };

  };

  services = {
    firecrawl = {
      enable = true;
      host = "127.0.0.1";
      openFirewall = false;
      bullAuthKeyFile = config.sops.secrets."FIRECRAWL/BULL_AUTH_KEY".path;
      openrouter = {
        enable = true;
        apiKeyFile = config.sops.secrets."AI_AGENT/OPENROUTER_API_KEY".path;
      };
    };

    open-webui = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
      package = pkgs.open-webui.overridePythonAttrs (old: {
        dependencies = old.dependencies ++ old.optional-dependencies.postgres;
      });

      environmentFile = config.sops.templates.openweb-ui-env.path;
      environment = {
        HOME = "/var/lib/open-webui";
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
}
