{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.sops) placeholder;
in
{
  sops.secrets = {
    "MCP/API_TOKEN" = { };
    "MCP/HASSIO_TOKEN" = { };
    "MCP/GITHUB_TOKEN" = { };
    "MCP/ANILIST_TOKEN" = { };
  };

  services = {

    # Runs like shit because iGPU ROCM doesn't work
    # Waiting for https://github.com/ollama/ollama/issues/2033 so it can run under vulkan
    ollama = {
      enable = true;
      # acceleration = "rocm";
      rocmOverrideGfx = "10.3.0";
      loadModels = [
        "gemma3:1b"
        "qwen3:1.7b"
      ];
      environmentVariables = {
        HCC_AMDGPU_TARGET = "gfx1031";
        OLLAMA_KEEP_ALIVE = "-1";
        OLLAMA_MAX_LOADED_MODELS = "2";
        OLLAMA_KV_CACHE_TYPE = "q4_0";
        OLLAMA_FLASH_ATTENTION = "1";
      };
    };

    mcpo = {
      enable = true;
      extraPackages = with pkgs; [
        git
        diffutils
        gh
      ];

      apiTokenFile = config.sops.secrets."MCP/API_TOKEN".path;
      environment = {
        SEARXNG_URL = "https://search.racci.dev";
        ANILIST_TOKEN = placeholder."MCP/ANILIST_TOKEN";
        MEMORY_FILE_PATH = "/var/lib/mcpo/memory.json";
      };

      configuration =
        let
          mk = config.services.mcpo.helpers;
        in
        {
          # General Tools
          sequential-thinking.command = lib.getExe pkgs.mcp-sequential-thinking;
          time = mk.uvxServerWithArgs "mcp-server-time" [ "--local-timezone=${config.time.timeZone}" ];
          filesystem = mk.npxServerWithArgs "@modelcontextprotocol/server-filesystem" [
            "/var/lib/mcpo/filesystem"
          ];

          # Developer Tools
          git = mk.uvxServer "mcp-server-git";
          nixos = mk.uvxServer "mcp-nixos";
          github = {
            type = "streamable-http";
            url = "https://api.githubcopilot.com/mcp";
            headers.Authorization = "Bearer ${placeholder."MCP/GITHUB_TOKEN"}";
          };

          # Information & Knowledge
          anilist = mk.npxServer "anilist-mcp";
          context7 = mk.npxServer "@upstash/context7-mcp";
          memory = mk.npxServer "@modelcontextprotocol/server-memory";
          whois = mk.npxServer "@bharathvaj/whois-mcp@latest";
          wikipedia = mk.uvxServerWithArgs "wikipedia-mcp" [ "--enable-cache" ];

          # Search, Web
          search = mk.npxServer "mcp-searxng";
          fetch = mk.uvxServerWithArgs "mcp-server-fetch" [ "--ignore-robots-txt" ];
          travel-planner = mk.npxServer "@gongrzhe/server-travelplanner-mcp";
          browser = {
            command = lib.getExe pkgs.playwright-mcp;
            args = [
              "--browser"
              "firefox"
              "--headless"
            ];
          };

          # Misc Tools
          hassio = {
            type = "sse";
            url = "https://hassio.racci.dev/mcp_server/sse";
            headers.Authorization = "Bearer ${placeholder."MCP/HASSIO_TOKEN"}";
          };
        };
    };
  };

  server = {
    dashboard.items.mcpo = {
      title = "MCPO";
      icon = "sh-basic-memory";
    };

    proxy.virtualHosts.mcpo = {
      ports = [ 8000 ];
      extraConfig = ''
        redir / /docs

        reverse_proxy http://localhost:8000
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];
}
