{
  config,
  ...
}:
let
  cfg = config.services.dockerRegistry;

  placeholder = config.sops.placeholder;
in
{
  sops = {
    secrets = {
      "REGISTRY/SECRET" = { };
      "REGISTRY/HTPASSWD" = { };
      "REGISTRY/S3_ACCESS_KEY" = { };
      "REGISTRY/S3_SECRET_KEY" = { };
    };
    templates.registryConfig = {
      owner = config.users.users.docker-registry.name;
      group = config.users.groups.docker-registry.name;
      restartUnits = [ "docker-registry.service" ];

      content = builtins.toJSON {
        version = "0.1";

        log = {
          level = "info";
          formatter = "json";
        };

        http =
          let
            srvCfg = config.services.dockerRegistry;
          in
          {
            secret = placeholder."REGISTRY/SECRET";
            addr = "0.0.0.0:${toString srvCfg.port}";
            host = "https://registry.racci.dev";
            relativeurls = false;

            maxconcurrentuploads = 5;
            timeout_read = "5m";
            timeout_write = "10m";
          };

        health.storagedriver = {
          enabled = true;
          interval = "10s";
          threshold = 3;
        };

        storage = {
          s3 = {
            accesskey = placeholder."REGISTRY/S3_ACCESS_KEY";
            secretkey = placeholder."REGISTRY/S3_SECRET_KEY";
            region = "us-east-1";
            regionendpoint = "https://minio.racci.dev";
            forcepathstyle = true;
            bucket = "registry";
            v4auth = true;
          };
        };
      };
    };
  };

  server = {
    proxy.virtualHosts.registry = {
      public = true;
      ports = [ cfg.port ];
      extraConfig = ''
        reverse_proxy http://localhost:${toString cfg.port} {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-Host {host}

          health_uri /
          health_interval 30s
          health_timeout 10s
          health_status 2xx

          # Timeouts for large image pushes/pulls
          transport http {
            read_timeout 10m
            write_timeout 10m
            dial_timeout 30s
          }
        }

        header {
          X-Docker-Registry "v2"
        }
      '';
    };
  };

  services.dockerRegistry = {
    enable = true;
    enableDelete = true;
    configFile = config.sops.templates.registryConfig.path;
  };

  systemd.services.docker-registry = {
    serviceConfig.LoadCredential = [ "htpasswd:${config.sops.secrets."REGISTRY/HTPASSWD".path}" ];

    environment = {
      OTEL_TRACES_EXPORTER = "none";
      REGISTRY_AUTH = "htpasswd";
      REGISTRY_AUTH_HTPASSWD_REALM = "Registry Realm";
      REGISTRY_AUTH_HTPASSWD_PATH = "%d/htpasswd";
    };
  };
}
