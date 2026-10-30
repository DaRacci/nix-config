_:
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  # Upstream nixpkgs removed both the MinIO package and its NixOS module.
  # Until storage moves to SeaweedFS, build MinIO from the pinned pre-removal
  # nixpkgs revision and run it with the module's service definition inlined.
  minioPkgs = inputs.nixpkgs-minio.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  # TEMPORARY: Strip knownVulnerabilities from minio to unblock build.
  # TODO: Remove once migrated off MinIO (SeaweedFS evaluation in progress).
  minio' = minioPkgs.minio.overrideAttrs (old: {
    meta = (old.meta or { }) // {
      knownVulnerabilities = [ ];
    };
  });

  listenAddress = ":9000";
  consoleAddress = ":9001";
  dataDir = "/var/lib/minio/data";
  configDir = "/var/lib/minio/config";
  certificatesDir = "/var/lib/minio/certs";
  credentialsFile = config.sops.secrets.MINIO_ROOT_CREDENTIALS.path;
in
{
  users = {
    users.minio = {
      group = "minio";
      uid = config.ids.uids.minio;
    };
    groups.minio.gid = config.ids.uids.minio;
  };

  sops.secrets = {
    MINIO_ROOT_CREDENTIALS = {
      inherit (config.users.users.minio) group;
      owner = config.users.users.minio.name;
      restartUnits = [ "minio.service" ];
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d '${configDir}' - minio minio - -"
      "d '${dataDir}' - minio minio - -"
      "d '${certificatesDir}' - minio minio - -"
    ];

    services.minio = {
      description = "Minio Object Storage";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      unitConfig.ConditionPathExists = credentialsFile;

      environment = {
        MINIO_DOMAIN = "minio.racci.dev";
        MINIO_BROWSER_REDIRECT_URL = "https://minio.racci.dev/console";
        MINIO_OPTS = "--certs-dir /var/lib/acme/";
        MINIO_REGION = "us-east-1";
        MINIO_BROWSER = "on";
      };

      serviceConfig = {
        Type = "simple";
        User = "minio";
        Group = "minio";
        EnvironmentFile = credentialsFile;
        ExecStart = "${minio'}/bin/minio server --json --address ${listenAddress} --console-address ${consoleAddress} --config-dir=${configDir} --certs-dir=${certificatesDir} ${dataDir}";
        LimitNOFILE = 65536;

        # hardening
        DevicePolicy = "closed";
        DeviceAllow = "";
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_UNIX"
        ];
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        # minio opens /proc/mounts on startup
        ProcSubset = "all";
        MemoryDenyWriteExecute = true;
        LockPersonality = true;
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        UMask = "0077";
      };
    };
  };

  server = {
    proxy.virtualHosts.minio = {
      aliases = [ "*.minio" ];
      ports = [
        9000
        9001
      ];
      extraConfig = ''
        redir /console /console/

        handle_path /console* {
          reverse_proxy http://localhost${consoleAddress}
        }

        reverse_proxy {
          to http://localhost${listenAddress}
        }
      '';
    };

    monitoring.scrapeConfigs.minio = {
      port = 443;
      metrics_path = "/minio/v2/metrics/cluster";
      scheme = "https";
      host = "minio.racci.dev";
      bearer_token_secret = "MONITORING/MINIO_PROMETHEUS_TOKEN";
    };
  };
}
