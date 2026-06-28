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
    optional
    optionals
    removePrefix
    mapAttrs'
    nameValuePair
    ;
  inherit (lib.types)
    str
    path
    port
    nullOr
    attrsOf
    submodule
    ;

  cfg = config.services.mnemosyne;

  hasSync = cfg.server.sync.enable || cfg.client.sync != { };
  hasMcp = cfg.server.mcp.enable;

  package = pkgs.mnemosyne-memory.overridePythonAttrs (base: {
    dependencies =
      (optionals hasMcp base.passthru.optional-dependencies.mcp)
      ++ (optionals hasSync base.passthru.optional-dependencies.sync);
  });

  mkCommand =
    cmd: cfg:
    if cfg.container == null then
      cmd
    else
      "${lib.getExe pkgs.bash} -c \"${lib.getExe pkgs.docker} exec --env-file <(env) -u ${cfg.user} ${cfg.container} ${cmd}\"";

  mkService =
    type: cfgAttr: ext:
    mkMerge [
      {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          DynamicUser = true;
          PrivateTmp = true;
          ProtectSystem = "full";
          ProtectHome = true;
          Restart = "on-failure";
        };
      }

      (mkIf (cfgAttr.container == null) {
        serviceConfig = {
          StateDirectory = "${removePrefix "/var/lib/" cfg.dataDir}/${type}";
          Environment = "MNEMOSYNE_DATA_DIR=${cfg.dataDir}/${type}";
        };
      })

      (mkIf (cfg.container != null) {
        serviceConfig = {
          SupplementaryGroups = [ "docker" ];
          ReadWritePaths = [ "/var/run/docker.sock" ];
        };
      })

      ext
    ];

  containerOptions = type: {
    container = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Docker container to run the ${type} inside.
        If null, the server runs natively on the host.

        Additionally, this will only work if the /nix/store is mounted inside the container.
      '';
    };

    user = mkOption {
      type = nullOr str;
      default = null;
      description = "User to run the ${type} as inside the container.";
    };
  };

  serverOptions =
    type: listenPort:
    (containerOptions "${type} server")
    // {
      enable = mkEnableOption "Mnemosyne ${type} server";

      host = mkOption {
        type = str;
        default = "127.0.0.1";
        description = "Host address for the ${type} server to listen on.";
      };

      port = mkOption {
        type = port;
        default = listenPort;
        description = "Port for the ${type} server to listen on.";
      };

      apiKeyFile = mkOption {
        type = nullOr path;
        default = null;
        description = "Runtime path to a file containing the API key for authentication.";
      };
    };
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
      sync = serverOptions "sync" 8765;
      mcp = serverOptions "mcp" 8766;
    };

    client = {
      sync = mkOption {
        description = "Sync client profiles for periodic sync to remote servers.";
        default = { };
        type = attrsOf (
          submodule (_: {
            options = (containerOptions "sync client") // {
              remote = mkOption {
                type = str;
                description = "Sync server URL (e.g. http://sync.example.com).";
              };

              interval = mkOption {
                type = str;
                default = "*:0/10";
                description = "Systemd OnCalendar interval for sync. Default runs every 10 minutes.";
              };

              apiKeyFile = mkOption {
                type = nullOr path;
                default = null;
                description = "Runtime path to a file containing the API key for authentication.";
              };
            };
          })
        );
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable && cfg.server.sync.enable) {
      systemd.services.mnemosyne-sync-server = mkService "sync" cfg.server.sync {
        description = "Mnemosyne Sync Server";
        environment = {
          PORT = toString cfg.server.sync.port;
          HOST = cfg.server.sync.host;
          API_KEY = mkIf (cfg.server.sync.apiKeyFile != null) "%d/mnemosyne-sync-api-key";
        };

        serviceConfig = {
          ExecStart = mkCommand "${lib.getExe package} sync-serve" cfg.server.sync;
          LoadCredential = optional (
            cfg.server.sync.apiKeyFile != null
          ) "mnemosyne-sync-api-key:${cfg.server.sync.apiKeyFile}";
        };
      };
    })

    (mkIf (cfg.enable && cfg.server.mcp.enable) {
      systemd.services.mnemosyne-mcp-server = mkService "mcp" cfg.server.mcp {
        description = "Mnemosyne MCP Server";
        environment = {
          PORT = toString cfg.server.mcp.port;
          HOST = cfg.server.mcp.host;
          API_KEY = mkIf (cfg.server.mcp.apiKeyFile != null) "%d/mnemosyne-mcp-api-key";
        };

        serviceConfig = {
          ExecStart = mkCommand "${lib.getExe package} mcp --transport sse" cfg.server.mcp;
          LoadCredential = optional (
            cfg.server.mcp.apiKeyFile != null
          ) "mnemosyne-mcp-api-key:${cfg.server.mcp.apiKeyFile}";
        };
      };
    })

    (mkIf (cfg.enable && cfg.client.sync != [ ]) {
      systemd.services =
        cfg.client.sync
        |> mapAttrs' (
          name: cfg:
          nameValuePair "mnemosyne-sync-client-${name}" (
            mkService "sync" cfg {
              description = "Mnemosyne sync client (${name})";

              environment = {
                REMOTE = cfg.remote;
                API_KEY = mkIf (cfg.apiKeyFile != null) "%d/mnemosyne-sync-api-key-${name}";
              };

              serviceConfig = {
                Type = "oneshot";
                LoadCredential = optional (
                  cfg.apiKeyFile != null
                ) "mnemosyne-sync-api-key-${name}:${cfg.apiKeyFile}";
                ExecStart = mkCommand "${lib.getExe package} sync" cfg;
              };
            }
          )
        );

      systemd.timers =
        cfg.client.sync
        |> mapAttrs' (
          name: cfg:
          nameValuePair "mnemosyne-sync-client-${name}" {
            description = "Mnemosyne sync timer (${name})";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = cfg.interval;
            };
          }
        );
    })
  ];
}
