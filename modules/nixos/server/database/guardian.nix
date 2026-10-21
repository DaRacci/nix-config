{
  isThisIOPrimaryHost,
  getIOPrimaryHostAttr,
  getOthersWhere,
  ...
}:
{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    escapeShellArgs
    getExe
    getExe'
    hasSuffix
    mkIf
    mkMerge
    mkOption
    optional
    types
    unique
    ;
  inherit (types)
    str
    listOf
    ;

  cfg = config.server.database;

  serversWithDatabases = getOthersWhere (
    cfg:
    (builtins.attrNames cfg.server.database.postgres) != [ ]
    || (builtins.attrNames cfg.server.database.redis) != [ ]
  );
  thisHostHasPostgresDatabases = builtins.length (builtins.attrNames cfg.postgres) > 0;
  thisHostHasRedisDatabases = builtins.length (builtins.attrNames cfg.redis) > 0;
  thisHostHasDatabaseDependencies = thisHostHasPostgresDatabases || thisHostHasRedisDatabases;

  guardianPort = 9876;
  ioHostname = cfg.host;
  postgresPort = getIOPrimaryHostAttr "services.postgresql.settings.port";
  redisPort = (getIOPrimaryHostAttr "services.redis.servers")."".port;

  waitForIoCommand = escapeShellArgs [
    (getExe' pkgs.wait-for-io-tools "wait-for-io")
    cfg.host
  ];
  waitForDatabasesCommand = escapeShellArgs [
    (getExe' pkgs.wait-for-io-tools "wait-for-io-databases")
    ioHostname
    (if thisHostHasPostgresDatabases then toString postgresPort else "")
    (if thisHostHasRedisDatabases then toString redisPort else "")
  ];
in
{
  options.server.database = {
    dependentServices = mkOption {
      type = listOf str;
      default = [ ];
      description = ''
        List of systemd service names that depend on io databases.
        These services will be automatically bound to the io-databases.target
        and will stop/start when databases become unavailable/available.
      '';
      apply = map (n: if hasSuffix ".service" n then n else "${n}.service");
    };
  };

  config = mkMerge [
    {
      sops.secrets."IO_GUARDIAN_PSK" = {
        sopsFile = "${self}/hosts/server/secrets.yaml";
      };
    }

    (mkIf (!isThisIOPrimaryHost && thisHostHasDatabaseDependencies) {
      server = {
        network.openPortsForSubnet.tcp = [ guardianPort ];

        database.dependentServices =
          config.server.database.postgres // config.server.database.redis
          |> builtins.attrNames
          |> unique
          |> builtins.filter (n: config.systemd.services ? ${n})
          |> map (n: "${n}.service");
      };

      # Target that represents "IO databases are online"
      # Services bind to this target to be controlled by database availability
      systemd.targets.io-databases = {
        description = "IO Databases Online";
        after = [
          "network-online.target"
          "wait-for-io-databases.service"
        ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ]; # Start at boot
        bindsTo = [ "wait-for-io-databases.service" ];
        partOf = [ "multi-user.target" ];
        requiredBy = cfg.dependentServices;
        upholds = cfg.dependentServices;
      };

      systemd.services = mkMerge [
        {
          io-guardian = {
            description = "IO Database Guardian WebSocket Server";
            wantedBy = [ "multi-user.target" ];
            after = [
              "network-online.target"
              "wait-for-io.service"
            ];
            wants = [ "network-online.target" ];

            serviceConfig = {
              Type = "simple";
              Restart = "always";
              RestartSec = "5s";
              LoadCredential = [ "psk:${config.sops.secrets."IO_GUARDIAN_PSK".path}" ];

              ExecStart = ''
                ${getExe pkgs.io-guardian-server} \
                  --host 0.0.0.0 \
                  --port ${toString guardianPort} \
                  --psk-file %d/psk
              '';

              # Run as root to allow systemctl commands
              # Security hardening still applied where possible
              ProtectHome = true;
              PrivateTmp = true;
              PrivateDevices = true;
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
            };
          };
        }

        {
          wait-for-io = {
            description = "Wait for an IO host to become reachable";
            after = [ "dhcpd.service" ];
            wants = [
              "network.target"
              "dhcpd.service"
            ];
            before = [ "network-online.target" ];
            wantedBy = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = waitForIoCommand;
            };
          };

          wait-for-io-databases = {
            description = "Wait for an IO database to become available";
            after = [
              "network-online.target"
              "wait-for-io.service"
            ];
            wants = [ "network-online.target" ];
            requires = [ "wait-for-io.service" ];
            requiredBy = [ "io-databases.target" ];
            path = [
              pkgs.toybox
            ]
            ++ (optional thisHostHasPostgresDatabases (getIOPrimaryHostAttr "services.postgresql.package"))
            ++ (optional thisHostHasRedisDatabases (getIOPrimaryHostAttr "services.redis.package"));

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "5min";
              ExecStart = waitForDatabasesCommand;
            };
          };
        }
      ];
    })

    (mkIf (isThisIOPrimaryHost && (builtins.length serversWithDatabases) > 0) {
      systemd.services = {
        io-database-coordinator = rec {
          description = "Coordinate database availability with remote clients via WebSocket";

          after = [
            "postgresql.service"
            "redis.service"
          ];
          bindsTo = after;
          partOf = bindsTo;
          wantedBy = [ "multi-user.target" ];

          environment.GUARDIAN_PORT = toString guardianPort;

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStopSec = "90s";
            LoadCredential = [ "psk:${config.sops.secrets."IO_GUARDIAN_PSK".path}" ];

            ExecStart = ''
              ${getExe pkgs.io-guardian-client} \
                --action undrain \
                --hosts ${concatStringsSep "," serversWithDatabases} \
                --psk-file %d/psk
            '';

            ExecStop = ''
              ${getExe pkgs.io-guardian-client} \
                --action drain \
                --hosts ${concatStringsSep "," serversWithDatabases} \
                --psk-file %d/psk
            '';
          };
        };
      };
    })
  ];
}
