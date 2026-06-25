{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    mkMerge
    optionalAttrs
    optionalString
    ;
  inherit (lib.types)
    bool
    str
    path
    port
    nullOr
    attrsOf
    submodule
    ;

  cfg = config.services.mnemosyne;

  svcSyncServer = "mnemosyne-sync-server";
  svcMcpServer = "mnemosyne-mcp-server";
in
{
  options.services.mnemosyne = {
    enable = mkEnableOption "Mnemosyne memory service";

    dataDir = mkOption {
      type = str;
      default = "/var/lib/mnemosyne";
      description = "Data directory for Mnemosyne state.";
    };

    syncServer = {
      enable = mkEnableOption "Mnemosyne sync server";

      host = mkOption {
        type = str;
        default = "127.0.0.1";
        description = "Host address for the sync server to listen on.";
      };

      port = mkOption {
        type = port;
        default = 8765;
        description = "Port for the sync server to listen on.";
      };
    };

    mcpServer = {
      enable = mkEnableOption "Mnemosyne MCP server";

      host = mkOption {
        type = str;
        default = "127.0.0.1";
        description = "Host address for the MCP server to listen on.";
      };

      port = mkOption {
        type = port;
        default = 8766;
        description = "Port for the MCP server to listen on.";
      };
    };

    syncClients = mkOption {
      description = "Sync client profiles for periodic sync to remote servers.";
      default = { };
      type = attrsOf (
        submodule (_client: {
          options = {
            remote = mkOption {
              type = str;
              description = "Sync server URL (e.g. http://sync.example.com:8765).";
            };

            interval = mkOption {
              type = str;
              default = "*:0/10";
              description = "Systemd OnCalendar interval for sync. Default runs every 10 minutes.";
            };

            container = mkOption {
              type = str;
              default = "hermes-agent";
              description = "Docker container name to exec the sync command in.";
            };

            user = mkOption {
              type = str;
              default = "hermes";
              description = "User to exec the sync command as inside the container.";
            };

            apiKeyFile = mkOption {
              type = nullOr path;
              default = null;
              description = "Path to a file containing the API key for authenticating to a Caddy reverse proxy with requireApiKey enabled.";
            };
          };
        })
      );
    };

    proxy = {
      enable = mkEnableOption "reverse proxy for Mnemosyne servers";

      requireApiKey = mkOption {
        type = bool;
        default = true;
        description = ''
          Enable API key authentication on the reverse proxy vhosts.
          Secrets are auto-generated via the api-key-auth proxy extension.
        '';
      };

      syncSubdomain = mkOption {
        type = nullOr str;
        default = null;
        description = "Subdomain for the sync server reverse proxy (e.g. 'sync' → sync.<domain>).";
      };

      mcpSubdomain = mkOption {
        type = nullOr str;
        default = null;
        description = "Subdomain for the MCP server reverse proxy (e.g. 'sync-mcp' → sync-mcp.<domain>).";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      systemd.services = mkMerge (
        [
          (mkIf cfg.syncServer.enable {
            "${svcSyncServer}" = {
              description = "Mnemosyne Sync Server";
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                DynamicUser = true;
                StateDirectory = lib.lists.last (lib.splitString "/" cfg.dataDir);
                ExecStart = "${lib.getExe pkgs.mnemosyne-memory} sync serve --host ${cfg.syncServer.host} --port ${toString cfg.syncServer.port}";
                Environment = "MNEMOSYNE_DATA_DIR=${cfg.dataDir}";
                Restart = "on-failure";
              };
            };
          })
          (mkIf cfg.mcpServer.enable {
            "${svcMcpServer}" = {
              description = "Mnemosyne MCP Server";
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                DynamicUser = true;
                StateDirectory = lib.lists.last (lib.splitString "/" cfg.dataDir);
                ExecStart = "${lib.getExe pkgs.mnemosyne-mcp} mcp --transport sse --host ${cfg.mcpServer.host} --port ${toString cfg.mcpServer.port}";
                Environment = "MNEMOSYNE_DATA_DIR=${cfg.dataDir}";
                Restart = "on-failure";
              };
            };
          })
        ]
        ++ map (
          clientName:
          let
            client = cfg.syncClients.${clientName};
            svcName = "mnemosyne-sync-client-${clientName}";
            apiKeyFlag = optionalString (
              client.apiKeyFile != null
            ) " -H \"Req-API-Key: $(cat %d/mnemosyne-sync-api-key-${clientName})\"";
          in
          mkIf (builtins.hasAttr clientName cfg.syncClients) {
            "${svcName}" = {
              description = "Mnemosyne sync client — ${clientName}";
              after = [ "docker.service" ];
              wants = [ "docker.service" ];
              serviceConfig = {
                Type = "oneshot";
                LoadCredential = mkIf (client.apiKeyFile != null) [
                  "mnemosyne-sync-api-key-${clientName}:${client.apiKeyFile}"
                ];
                ExecStart = "${lib.getExe pkgs.docker} exec -u ${client.user} ${client.container} mnemosyne sync --remote ${client.remote}${apiKeyFlag}";
              };
            };
          }
        ) (builtins.attrNames cfg.syncClients)
      );

      systemd.timers = mkMerge (
        map (
          clientName:
          let
            timerName = "mnemosyne-sync-client-${clientName}";
          in
          mkIf (builtins.hasAttr clientName cfg.syncClients) {
            "${timerName}" = {
              description = "Mnemosyne sync timer — ${clientName}";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = cfg.syncClients.${clientName}.interval;
              };
            };
          }
        ) (builtins.attrNames cfg.syncClients)
      );
    })

    (mkIf (cfg.enable && cfg.caddy.enable && config.host.device.role == "server") {
      server.proxy.virtualHosts = mkMerge [
        (optionalAttrs (cfg.syncServer.enable && cfg.caddy.syncSubdomain != null) {
          "${cfg.caddy.syncSubdomain}" = {
            ports = [ cfg.syncServer.port ];
            extraConfig = "reverse_proxy ${cfg.syncServer.host}:${toString cfg.syncServer.port}";
            requireApiKey = {
              enable = cfg.caddy.requireApiKey;
            };
          };
        })
        (optionalAttrs (cfg.mcpServer.enable && cfg.caddy.mcpSubdomain != null) {
          "${cfg.caddy.mcpSubdomain}" = {
            ports = [ cfg.mcpServer.port ];
            extraConfig = "reverse_proxy ${cfg.mcpServer.host}:${toString cfg.mcpServer.port}";
            requireApiKey = {
              enable = cfg.caddy.requireApiKey;
            };
          };
        })
      ];
    })
  ];
}
