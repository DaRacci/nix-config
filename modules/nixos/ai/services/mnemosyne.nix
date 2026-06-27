{
  config,
  pkgs,
  lib,
  deviceType ? null,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    mkMerge
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
in
{
  options.services.mnemosyne = {
    enable = mkEnableOption "Mnemosyne memory service";

    dataDir = mkOption {
      type = str;
      default = "/var/lib/mnemosyne";
      description = "Data directory for Mnemosyne state.";
    };

    server = {
      sync = {
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

        container = mkOption {
          type = nullOr str;
          default = null;
          description = "Docker container to run the sync server inside. If null, the server runs natively on the host.";
        };

        user = mkOption {
          type = str;
          default = "mnemosyne";
          description = "User to run the server as inside the container.";
        };
      };

      mcp = {
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

        container = mkOption {
          type = nullOr str;
          default = null;
          description = "Docker container to run the MCP server inside. If null, the server runs natively on the host.";
        };

        user = mkOption {
          type = str;
          default = "mnemosyne";
          description = "User to run the server as inside the container.";
        };
      };
    };

    client = {
      sync = mkOption {
        description = "Sync client profiles for periodic sync to remote servers.";
        default = { };
        type = attrsOf (
          submodule (_: {
            options = {
              enable = mkEnableOption "this sync client profile";

              remote = mkOption {
                type = str;
                description = "Sync server URL (e.g. http://sync.example.com).";
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
    };

    caddy = {
      enable = mkEnableOption "Caddy reverse proxy for Mnemosyne servers";

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

  imports = lib.optionals (deviceType == "server") [ ./mnemosyne-caddy.nix ];

  config = mkMerge [
    (mkIf cfg.enable {
      systemd.services = mkMerge (
        [
          (mkIf cfg.server.sync.enable {
            "mnemosyne-sync-server" = {
              description = "Mnemosyne Sync Server";
              wantedBy = [ "multi-user.target" ];
              after = mkIf (cfg.server.sync.container != null) [ "docker.service" ];
              wants = mkIf (cfg.server.sync.container != null) [ "docker.service" ];
              serviceConfig = mkMerge [
                (mkIf (cfg.server.sync.container == null) {
                  DynamicUser = true;
                  StateDirectory = "${lib.removePrefix "/var/lib/" cfg.dataDir}/sync";
                  ExecStart = "${lib.getExe pkgs.mnemosyne-memory} sync serve --host ${cfg.server.sync.host} --port ${toString cfg.server.sync.port}";
                  Environment = "MNEMOSYNE_DATA_DIR=${cfg.dataDir}/sync";
                })
                (mkIf (cfg.server.sync.container != null) {
                  ExecStart = "${lib.getExe pkgs.docker} exec -u ${cfg.server.sync.user} ${cfg.server.sync.container} mnemosyne sync serve --host ${cfg.server.sync.host} --port ${toString cfg.server.sync.port}";
                })
                {
                  Restart = "on-failure";
                }
              ];
            };
          })
          (mkIf cfg.server.mcp.enable {
            "mnemosyne-mcp-server" = {
              description = "Mnemosyne MCP Server";
              wantedBy = [ "multi-user.target" ];
              after = mkIf (cfg.server.mcp.container != null) [ "docker.service" ];
              wants = mkIf (cfg.server.mcp.container != null) [ "docker.service" ];
              serviceConfig = mkMerge [
                (mkIf (cfg.server.mcp.container == null) {
                  DynamicUser = true;
                  StateDirectory = "${lib.removePrefix "/var/lib/" cfg.dataDir}/mcp";
                  ExecStart = "${lib.getExe pkgs.mnemosyne-mcp} mcp --transport sse --host ${cfg.server.mcp.host} --port ${toString cfg.server.mcp.port}";
                  Environment = "MNEMOSYNE_DATA_DIR=${cfg.dataDir}/mcp";
                })
                (mkIf (cfg.server.mcp.container != null) {
                  ExecStart = "${lib.getExe pkgs.docker} exec -u ${cfg.server.mcp.user} ${cfg.server.mcp.container} mnemosyne mcp --transport sse --host ${cfg.server.mcp.host} --port ${toString cfg.server.mcp.port}";
                })
                {
                  Restart = "on-failure";
                }
              ];
            };
          })
        ]
        ++ map (
          clientName:
          let
            client = cfg.client.sync.${clientName};
            svcName = "mnemosyne-sync-client-${clientName}";
            apiKeyFlag = optionalString (
              client.apiKeyFile != null
            ) " -H \"Req-API-Key: $(cat %d/mnemosyne-sync-api-key-${clientName})\"";
          in
          mkIf client.enable {
            "${svcName}" = {
              description = "Mnemosyne sync client — ${clientName}";
              after = [ "docker.service" ];
              wants = [ "docker.service" ];
              serviceConfig = {
                Type = "oneshot";
                LoadCredential = mkIf (client.apiKeyFile != null) [
                  "mnemosyne-sync-api-key-${clientName}:${client.apiKeyFile}"
                ];
                ExecStart = "${lib.getExe pkgs.bash} -c \"${lib.getExe pkgs.docker} exec -u ${client.user} ${client.container} mnemosyne sync --remote ${client.remote}${apiKeyFlag}\"";
              };
            };
          }
        ) (builtins.attrNames cfg.client.sync)
      );

      systemd.timers = mkMerge (
        map (
          clientName:
          let
            client = cfg.client.sync.${clientName};
            timerName = "mnemosyne-sync-client-${clientName}";
          in
          mkIf client.enable {
            "${timerName}" = {
              description = "Mnemosyne sync timer — ${clientName}";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = client.interval;
              };
            };
          }
        ) (builtins.attrNames cfg.client.sync)
      );
    })
  ];
}
