{
  ...
}:
{
  services = {
    # TODO - Add fallback ollama for when nixmi is down
    open-webui = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
      environment = {
        OLLAMA_BASE_URLS = "http://nixmi:11434";

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
  };
}
