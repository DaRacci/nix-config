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
  dbHostname = cfg.host;
  postgresPort = getIOPrimaryHostAttr "services.postgresql.settings.port";
  redisPort = (getIOPrimaryHostAttr "services.redis.servers")."".port;

  waitForDbPrimaryCommand = escapeShellArgs [
    (getExe' pkgs.wait-for-db-tools "wait-for-db-primary")
    cfg.host
  ];
  waitForDatabasesCommand = escapeShellArgs [
    (getExe' pkgs.wait-for-db-tools "wait-for-db-databases")
    dbHostname
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
        List of systemd service names that depend on databases.
        These services will be automatically bound to the db-databases.target
        and will stop/start when databases become unavailable/available.
      '';
      apply = map (n: if hasSuffix ".service" n then n else "${n}.service");
    };
  };

  config = mkMerge [
    {
      sops.secrets."DB_GUARDIAN_PSK" = {
        sopsFile = "${self}/hosts/server/secrets.yaml";
        # Restart whichever side of the guardian owns the PSK on this host.
        # sops-nix uses try-restart, which errors on units that do not exist, so only list units this host actually defines.
        restartUnits =
          optional (!isThisIOPrimaryHost && thisHostHasDatabaseDependencies) "db-guardian.service"
          ++ optional (
            isThisIOPrimaryHost && (builtins.length serversWithDatabases) > 0
          ) "db-database-coordinator.service";
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

      # Target that represents "databases are online"
      # Services bind to this target to be controlled by database availability
      systemd.targets.db-databases = {
        description = "Databases Online";
        after = [
          "network-online.target"
          "wait-for-db-databases.service"
        ];
        wants = [ "network-online.target" ];
        # Start at boot, and again whenever the readiness check restarts.
        # bindsTo stops this target when the check stops, so without the second wantedBy a restarted check would leave the target down.
        wantedBy = [
          "multi-user.target"
          "wait-for-db-databases.service"
        ];
        bindsTo = [ "wait-for-db-databases.service" ];
        partOf = [ "multi-user.target" ];
        requiredBy = cfg.dependentServices;
        upholds = cfg.dependentServices;
      };

      systemd.services = mkMerge [
        {
          db-guardian = {
            description = "Database Guardian WebSocket Server";
            wantedBy = [ "multi-user.target" ];
            after = [
              "network-online.target"
              "wait-for-db-primary.service"
            ];
            wants = [ "network-online.target" ];

            serviceConfig = {
              Type = "simple";
              Restart = "always";
              RestartSec = "5s";
              LoadCredential = [ "psk:${config.sops.secrets."DB_GUARDIAN_PSK".path}" ];

              ExecStart = ''
                ${getExe pkgs.db-guardian-server} \
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
          wait-for-db-primary = {
            description = "Wait for the database primary host to become reachable";
            after = [ "dhcpd.service" ];
            wants = [
              "network.target"
              "dhcpd.service"
            ];
            before = [ "network-online.target" ];
            wantedBy = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = waitForDbPrimaryCommand;
            };
          };

          wait-for-db-databases = {
            description = "Wait for a database to become available";
            after = [
              "network-online.target"
              "wait-for-db-primary.service"
            ];
            wants = [ "network-online.target" ];
            requires = [ "wait-for-db-primary.service" ];
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
        db-database-coordinator = rec {
          description = "Coordinate database availability with remote clients via WebSocket";

          after = [
            "postgresql.service"
            "redis.service"
          ];
          bindsTo = after;
          partOf = bindsTo;
          # bindsTo/partOf only propagate stop and restart.
          # Start the coordinator again whenever either database starts,
          # otherwise a database restart leaves it dead and clients stay drained.
          wantedBy = [
            "multi-user.target"
            "postgresql.service"
            "redis.service"
          ];

          environment.GUARDIAN_PORT = toString guardianPort;

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "30s";
            TimeoutStartSec = "120s";
            TimeoutStopSec = "90s";
            LoadCredential = [ "psk:${config.sops.secrets."DB_GUARDIAN_PSK".path}" ];

            ExecStart = ''
              ${getExe pkgs.db-guardian-client} \
                --action undrain \
                --hosts ${concatStringsSep "," serversWithDatabases} \
                --psk-file %d/psk \
                --fail-fast
            '';

            ExecStop = ''
              ${getExe pkgs.db-guardian-client} \
                --action drain \
                --hosts ${concatStringsSep "," serversWithDatabases} \
                --psk-file %d/psk
            '';
          };
        };

        # Re-assert the desired state while the coordinator is active.
        # The initial undrain can be missed by a client that boots late,
        # or by a target that stops after the coordinator already went active.
        db-database-coordinator-reconcile = {
          description = "Re-assert database availability to guardian clients";
          bindsTo = [ "db-database-coordinator.service" ];
          after = [ "db-database-coordinator.service" ];

          environment.GUARDIAN_PORT = toString guardianPort;

          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "120s";
            LoadCredential = [ "psk:${config.sops.secrets."DB_GUARDIAN_PSK".path}" ];

            ExecStart = ''
              ${getExe pkgs.db-guardian-client} \
                --action undrain \
                --hosts ${concatStringsSep "," serversWithDatabases} \
                --psk-file %d/psk \
                --fail-fast
            '';
          };
        };
      };

      systemd.timers.db-database-coordinator-reconcile = {
        description = "Periodically re-assert database availability to guardian clients";
        # Start and stop with the coordinator so an intentional drain is not undone by the reconciliation loop.
        wantedBy = [ "db-database-coordinator.service" ];
        partOf = [ "db-database-coordinator.service" ];
        after = [ "db-database-coordinator.service" ];

        timerConfig = {
          OnActiveSec = "5min";
          OnUnitActiveSec = "5min";
        };
      };
    })
  ];
}
