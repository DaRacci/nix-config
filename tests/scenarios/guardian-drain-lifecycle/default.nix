{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    getExe
    mkIf
    mkMerge
    mkOption
    types
    ;
  inherit (types)
    bool
    nullOr
    str
    enum
    ;

  cfg = config.guardianDrainTest;

  psk = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
  pskPath = "/etc/io-guardian-psk";
  guardianPort = 9876;

  coordinatorScript = pkgs.writeShellApplication {
    name = "guardian-coordinator";
    runtimeInputs = [ pkgs.io-guardian-client ];
    text = ''
      set -e
      ACTION="$1"
      GUARDIAN_HOST="${cfg.guardianHost}"
      PSK_FILE="${pskPath}"

      if [ -z "$ACTION" ]; then
        echo "Usage: guardian-coordinator <undrain|drain>"
        exit 1
      fi

      echo "Running $ACTION against $GUARDIAN_HOST..."

      for i in $(seq 30); do
        if io-guardian-client \
          --action "$ACTION" \
          --hosts "$GUARDIAN_HOST" \
          --psk-file "$PSK_FILE" \
          --timeout 5 \
          --fail-fast 2>&1
        then
          echo "$ACTION successful"
          exit 0
        fi
        echo "Attempt $i/30 failed, retrying in 2s..."
        sleep 2
      done

      echo "Failed to $ACTION after 30 attempts"
      exit 1
    '';
  };

  waitForPGScript = pkgs.writeShellApplication {
    name = "wait-for-io-databases";
    runtimeInputs = [ pkgs.postgresql ];
    text = ''
      IO_HOSTNAME="${cfg.ioPrimaryHost}"
      POSTGRES_PORT="5432"
      MAX_ATTEMPTS=60
      RETRY_INTERVAL=5

      echo "Waiting for PostgreSQL on $IO_HOSTNAME:$POSTGRES_PORT..."

      attempt=1
      while [ $attempt -le $MAX_ATTEMPTS ]; do
        if pg_isready -h "$IO_HOSTNAME" -p "$POSTGRES_PORT" -t 5 >/dev/null 2>&1; then
          echo "PostgreSQL is ready (attempt $attempt)"
          exit 0
        fi
        echo "Attempt $attempt/$MAX_ATTEMPTS: PostgreSQL not ready"
        attempt=$((attempt + 1))
        sleep $RETRY_INTERVAL
      done

      echo "Timeout waiting for PostgreSQL after $MAX_ATTEMPTS attempts"
      exit 1
    '';
  };
in
{
  options.guardianDrainTest = {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Enable guardian drain lifecycle test module";
    };
    role = mkOption {
      type = nullOr (enum [
        "io-primary"
        "guardian"
      ]);
      default = null;
      description = "Node role in the drain lifecycle";
    };
    ioPrimaryHost = mkOption {
      type = str;
      default = "nixio";
      description = "Hostname of the IO primary (PostgreSQL host)";
    };
    guardianHost = mkOption {
      type = str;
      default = "nixdev";
      description = "Hostname of the guardian WebSocket server";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Common: PSK file at known path
    {
      environment.etc."io-guardian-psk".text = psk;
    }

    # IO Primary: PostgreSQL + coordinator
    (mkIf (cfg.role == "io-primary") {
      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        authentication = ''
          local all all trust
          host all all all trust
        '';
        ensureDatabases = [ "guardian_test" ];
        ensureUsers = [ { name = "testuser"; } ];
      };
      networking.firewall.allowedTCPPorts = [
        5432
        guardianPort
      ];

      systemd.services.io-database-coordinator = {
        description = "Coordinate database availability with remote clients via WebSocket";
        after = [ "postgresql.service" ];
        bindsTo = [ "postgresql.service" ];
        partOf = [ "postgresql.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStopSec = "90s";
          ExecStart = "${getExe coordinatorScript} undrain";
          ExecStop = "${getExe coordinatorScript} drain";
        };
      };
    })

    # Guardian host: io-guardian + wait-for-io-databases + target + dependent service
    (mkIf (cfg.role == "guardian") {
      networking.firewall.allowedTCPPorts = [ guardianPort ];

      systemd.targets.io-databases = {
        description = "IO Databases Online";
        after = [
          "network-online.target"
          "wait-for-io-databases.service"
        ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        bindsTo = [ "wait-for-io-databases.service" ];
        partOf = [ "multi-user.target" ];
        upholds = [ "test-dependent.service" ];
        requiredBy = [ "test-dependent.service" ];
      };

      systemd.services = {
        io-guardian = {
          description = "IO Database Guardian WebSocket Server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RestartSec = "5s";
            ExecStart = ''
              ${getExe pkgs.io-guardian-server} \
                --host 0.0.0.0 \
                --port ${toString guardianPort} \
                --psk-file ${pskPath}
            '';
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
          };
        };

        wait-for-io-databases = {
          description = "Wait for IO database to become available";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          requiredBy = [ "io-databases.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "5min";
            ExecStart = getExe waitForPGScript;
          };
        };

        test-dependent = {
          description = "Test dependent service — starts only when IO databases are available";
          after = [ "io-databases.target" ];
          requires = [ "io-databases.target" ];
          wantedBy = [ "io-databases.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
          };
        };
      };
    })
  ]);
}
