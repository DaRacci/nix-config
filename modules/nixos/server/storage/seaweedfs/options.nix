{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    ;

  inherit (lib.types)
    attrs
    attrsOf
    bool
    float
    ints
    lines
    listOf
    nullOr
    package
    path
    port
    str
    submodule
    ;

  swLib = import ./lib.nix {
    inherit config lib;
  };

  cfg = config.services.seaweedfs;

  mkComponentOptions =
    {
      name,
      httpPort ? null,
      grpcPort ? null,
      grpcPortNullable ? false,
      ip ? "127.0.0.1",
      ipBind ? true,
      dataDir ? null,
      metricsPort ? true,
      metricsIp ? null,
      extraArgs ? true,
    }:
    {
      enable = mkEnableOption "SeaweedFS ${name} service";
    }
    // lib.optionalAttrs (httpPort != null) {
      port = mkOption {
        type = port;
        default = httpPort;
        description = "${name} HTTP listen port.";
      };
    }
    // lib.optionalAttrs (grpcPort != null || grpcPortNullable) {
      grpcPort = mkOption {
        type = if grpcPortNullable then nullOr port else port;
        default = grpcPort;
        description = "${name} gRPC listen port.";
      };
    }
    // lib.optionalAttrs (ip != null) {
      ip = mkOption {
        type = str;
        default = ip;
        description = "${name} advertised IP or hostname.";
      };
    }
    // lib.optionalAttrs (ip != null && ipBind) {
      ipBind = mkOption {
        type = str;
        default = "";
        description = "${name} bind IP. Empty uses ip.";
      };
    }
    // lib.optionalAttrs (dataDir != null) {
      dataDir = mkOption {
        type = str;
        default = dataDir;
        description = "${name} data directory.";
      };
    }
    // lib.optionalAttrs metricsPort {
      metricsPort = mkOption {
        type = nullOr port;
        default = null;
        description = "${name} metrics port.";
      };
    }
    // lib.optionalAttrs (metricsIp != null) {
      metricsIp = mkOption {
        type = str;
        default = metricsIp;
        description = "${name} metrics bind IP.";
      };
    }
    // lib.optionalAttrs extraArgs {
      extraArgs = mkOption {
        type = listOf str;
        default = [ ];
        description = "Extra CLI args passed to weed ${name}.";
      };
    };
in
{
  options.services.seaweedfs = {
    enable = mkEnableOption "SeaweedFS";

    openFirewall = mkOption {
      type = bool;
      default = false;
      description = "Whether to open ports in firewall for SeaweedFS services.";
    };

    package = mkOption {
      type = package;
      default = pkgs.seaweedfs;
      defaultText = literalExpression "pkgs.seaweedfs";
      description = "SeaweedFS package to use.";
    };

    master =
      mkComponentOptions {
        name = "master";
        httpPort = 9333;
        grpcPort = 19333;
        dataDir = "${swLib.baseDir}/master";
      }
      // {
        peers = mkOption {
          type = listOf str;
          default = [ ];
          description = "Master peers list.";
        };

        volumeSizeLimitMB = mkOption {
          type = ints.positive;
          default = 30000;
          description = "Stop directing writes to oversized volumes.";
        };

        fileSizeLimitMB = mkOption {
          type = ints.positive;
          default = 256;
          description = "Limit max file size accepted by master submit path.";
        };

        volumePreallocate = mkOption {
          type = bool;
          default = false;
          description = "Preallocate disk space for volumes.";
        };

        defaultReplication = mkOption {
          type = str;
          default = "";
          description = "Default replication type.";
        };

        electionTimeout = mkOption {
          type = str;
          default = "10s";
          description = "Master election timeout.";
        };

        heartbeatInterval = mkOption {
          type = str;
          default = "300ms";
          description = "Master heartbeat interval.";
        };

        garbageThreshold = mkOption {
          type = float;
          default = 0.3;
          description = "Vacuum garbage threshold.";
        };

        whiteList = mkOption {
          type = listOf str;
          default = [ ];
          description = "IPs allowed for write operations.";
        };

        disableHttp = mkOption {
          type = bool;
          default = false;
          description = "Disable master HTTP API and only allow gRPC.";
        };

        telemetry = mkOption {
          type = bool;
          default = true;
          description = "Enable anonymous telemetry.";
        };

        telemetryUrl = mkOption {
          type = str;
          default = "https://telemetry.seaweedfs.com/api/collect";
          description = "Telemetry endpoint URL.";
        };

        maxParallelVacuum = mkOption {
          type = ints.positive;
          default = 1;
          description = "Max parallel vacuum operations per volume server.";
        };
      };

    volume =
      mkComponentOptions {
        name = "volume";
        httpPort = 8080;
        grpcPort = 18080;
        dataDir = "${swLib.baseDir}/volume";
      }
      // {
        publicPort = mkOption {
          type = nullOr port;
          default = null;
          description = "Volume public HTTP port override.";
        };

        id = mkOption {
          type = nullOr str;
          default = null;
          description = "Volume server ID override.";
        };

        publicUrl = mkOption {
          type = nullOr str;
          default = null;
          description = "Publicly reachable volume URL for master/filer redirects.";
        };

        master = mkOption {
          type = listOf str;
          default = [ ];
          description = "Master addresses list.";
        };

        maxVolumes = mkOption {
          type = ints.unsigned;
          default = 8;
          description = "Max number of volumes.";
        };

        dataCenter = mkOption {
          type = str;
          default = "";
          description = "Volume data center label.";
        };

        rack = mkOption {
          type = str;
          default = "";
          description = "Volume rack label.";
        };

        disk = mkOption {
          type = str;
          default = "";
          description = "Volume disk type label.";
        };

        tags = mkOption {
          type = nullOr str;
          default = null;
          description = "Per-data-dir volume tags in weed format.";
        };

        idxDir = mkOption {
          type = nullOr str;
          default = null;
          description = "Directory for index files.";
        };

        index = mkOption {
          type = lib.types.enum [
            "memory"
            "leveldb"
            "leveldbMedium"
            "leveldbLarge"
          ];
          default = "memory";
          description = "Needle map index backend.";
        };

        readMode = mkOption {
          type = lib.types.enum [
            "local"
            "proxy"
            "redirect"
          ];
          default = "proxy";
          description = "Read behavior for non-local volumes.";
        };

        minFreeSpace = mkOption {
          type = str;
          default = "1";
          description = "Minimum free space threshold.";
        };

        fileSizeLimitMB = mkOption {
          type = ints.positive;
          default = 256;
          description = "Max file size handled by volume server.";
        };

        whiteList = mkOption {
          type = listOf str;
          default = [ ];
          description = "IPs allowed for write operations.";
        };
      };

    filer =
      mkComponentOptions {
        name = "filer";
        httpPort = 8888;
        grpcPort = 18888;
        dataDir = "${swLib.baseDir}/filer";
      }
      // {
        publicPort = mkOption {
          type = nullOr port;
          default = null;
          description = "Filer readonly public port override.";
        };

        collection = mkOption {
          type = str;
          default = "";
          description = "Default filer collection.";
        };

        defaultReplicaPlacement = mkOption {
          type = str;
          default = "";
          description = "Default filer replica placement.";
        };

        master = mkOption {
          type = listOf str;
          default = [ ];
          description = "Master addresses list.";
        };

        maxMB = mkOption {
          type = ints.positive;
          default = 4;
          description = "Split files larger than this size.";
        };

        disableHttp = mkOption {
          type = bool;
          default = false;
          description = "Disable filer HTTP API and only allow gRPC.";
        };

        allowedOrigins = mkOption {
          type = str;
          default = "*";
          description = "CORS allowed origins.";
        };

        exposeDirectoryData = mkOption {
          type = bool;
          default = true;
          description = "Expose directory metadata in filer UI.";
        };

        s3 =
          mkComponentOptions {
            name = "s3";
            httpPort = 8333;
            grpcPortNullable = true;
            ip = null;
            ipBind = false;
            metricsPort = false;
          }
          // {
            httpsPort = mkOption {
              type = nullOr port;
              default = null;
              description = "S3 HTTPS listen port.";
            };

            allowDeleteBucketNotEmpty = mkOption {
              type = bool;
              default = false;
              description = "Allow deleting non-empty buckets.";
            };

            allowEmptyFolder = mkOption {
              type = bool;
              default = true;
              description = "Allow empty folders.";
            };

            allowedOrigins = mkOption {
              type = str;
              default = "*";
              description = "S3 CORS allowed origins.";
            };

            domainName = mkOption {
              type = nullOr str;
              default = null;
              description = "Virtual-hosted-style S3 domain suffix.";
            };

            dataCenter = mkOption {
              type = str;
              default = "";
              description = "Preferred data center for S3 reads/writes.";
            };

            cert = {
              file = mkOption {
                type = nullOr path;
                default = null;
                description = "S3 TLS certificate file path.";
              };

              key = mkOption {
                type = nullOr path;
                default = null;
                description = "S3 TLS private key file path.";
              };
            };

            auditLogConfig = mkOption {
              type = nullOr path;
              default = null;
              description = "S3 audit log config path.";
            };

            config = mkOption {
              type = attrs;
              default = { };
              description = ''
                Freeform S3 configuration document.
                The `identities` and `policies` options are rendered into it, and any other key passes through unchanged.
              '';
            };

            configFile = mkOption {
              type = nullOr path;
              default = null;
              internal = true;
              description = "Rendered S3 configuration file path.";
            };

            externalUrl = mkOption {
              type = nullOr str;
              default = null;
              description = "External S3 URL advertised by SeaweedFS.";
            };

            identities = mkOption {
              type = attrsOf (
                submodule (
                  { name, ... }:
                  let
                    upperName = lib.toUpper (lib.replaceStrings [ "-" "." ] [ "_" "_" ] name);
                  in
                  {
                    options = {
                      accessKey = mkOption {
                        type = nullOr str;
                        default = null;
                        description = ''
                          Literal access key.
                          When null, the key is read from the environment variable named by `accessKeyEnv`.
                        '';
                      };

                      accessKeyEnv = mkOption {
                        type = str;
                        default = "S3_${upperName}_ACCESS_KEY";
                        description = "Environment variable the filer expands for the access key.";
                      };

                      accessKeySecret = mkOption {
                        type = str;
                        default = "S3/${upperName}_ACCESS_KEY";
                        description = "SOPS secret that populates `accessKeyEnv`.";
                      };

                      secretKey = mkOption {
                        type = nullOr str;
                        default = null;
                        description = ''
                          Literal secret key.
                          When null, the key is read from the environment variable named by `secretKeyEnv`.
                        '';
                      };

                      secretKeyEnv = mkOption {
                        type = str;
                        default = "S3_${upperName}_SECRET_KEY";
                        description = "Environment variable the filer expands for the secret key.";
                      };

                      secretKeySecret = mkOption {
                        type = str;
                        default = "S3/${upperName}_SECRET_KEY";
                        description = "SOPS secret that populates `secretKeyEnv`.";
                      };

                      policies = mkOption {
                        type = listOf str;
                        default = [ ];
                        description = "Policy names from `services.seaweedfs.filer.s3.policies`.";
                      };

                      disabled = mkOption {
                        type = bool;
                        default = false;
                        description = "Reject every request made with this identity.";
                      };
                    };
                  }
                )
              );
              default = { };
              description = ''
                S3 identities, keyed by identity name.
                They are rendered into `services.seaweedfs.filer.s3.config` alongside whatever that option declares.
              '';
            };

            policies = mkOption {
              type = attrsOf attrs;
              default = { };
              description = ''
                IAM policy documents keyed by policy name.
                Identities reference them through `services.seaweedfs.filer.s3.identities.<name>.policies`.
              '';
            };

            buckets = mkOption {
              type = attrsOf (submodule {
                options = {
                  owner = mkOption {
                    type = str;
                    description = "Identity name that owns the bucket.";
                  };

                  withLock = mkOption {
                    type = bool;
                    default = false;
                    description = "Enable S3 Object Lock, which also enables versioning.";
                  };

                  versioning = mkOption {
                    type = nullOr (
                      lib.types.enum [
                        "Enabled"
                        "Suspended"
                      ]
                    );
                    default = null;
                    description = ''
                      Versioning status.
                      Null leaves the bucket unconfigured, and Object Lock does not allow suspending versioning.
                    '';
                  };

                  quotaMB = mkOption {
                    type = nullOr ints.positive;
                    default = null;
                    description = ''
                      Bucket quota in MiB.
                      The quota is recorded on the bucket; exceeding it does not block writes without a
                      `s3.bucket.quota.enforce` pass.
                    '';
                  };
                };
              });
              default = { };
              description = ''
                Buckets created at boot, keyed by bucket name.
                The owner must be an identity from `services.seaweedfs.filer.s3.identities`.
              '';
            };
          };

        tomlConfig = mkOption {
          type = nullOr lines;
          default = null;
          description = "Direct TOML content for filer.toml.";
        };

        webdav =
          mkComponentOptions {
            name = "webdav";
            httpPort = 7333;
            ip = null;
            ipBind = false;
            metricsPort = false;
          }
          // {
            path = mkOption {
              type = str;
              default = "/";
              description = "Remote filer path exposed over WebDAV.";
            };

            collection = mkOption {
              type = str;
              default = "";
              description = "WebDAV collection name.";
            };

            cacheDir = mkOption {
              type = str;
              default = "${swLib.baseDir}/webdav-cache";
              description = "WebDAV local cache directory.";
            };

            cacheCapacityMB = mkOption {
              type = ints.positive;
              default = 1000;
              description = "WebDAV cache size in MB.";
            };

            disk = mkOption {
              type = str;
              default = "";
              description = "WebDAV disk type label.";
            };

            replication = mkOption {
              type = str;
              default = "";
              description = "WebDAV replication strategy.";
            };
          };
      };

    admin =
      mkComponentOptions {
        name = "admin";
        httpPort = 23646;
        grpcPort = 33646;
        grpcPortNullable = true;
        ipBind = false;
        dataDir = "${swLib.baseDir}/admin";
        metricsIp = "";
      }
      // {
        legacyPort = mkOption {
          type = nullOr port;
          default = null;
          description = "Admin legacy compatibility port.";
        };

        master = mkOption {
          type = listOf str;
          default = [ ];
          description = "Master addresses list.";
        };

        filerGroup = mkOption {
          type = str;
          default = "";
          description = "Filer group used by admin.";
        };

        urlPrefix = mkOption {
          type = str;
          default = "";
          description = "Admin URL prefix when reverse proxied under subpath.";
        };

        uploadMaxSizeMB = mkOption {
          type = nullOr ints.unsigned;
          default = null;
          description = "Max admin UI upload size in MB.";
        };
      };

    worker =
      mkComponentOptions {
        name = "worker";
        ip = null;
        ipBind = false;
        metricsIp = "0.0.0.0";
      }
      // {
        admin = mkOption {
          type = str;
          default = "127.0.0.1:23646";
          description = "Admin server address used by worker.";
        };

        id = mkOption {
          type = nullOr str;
          default = null;
          description = "Worker ID.";
        };

        workingDir = mkOption {
          type = str;
          default = "${swLib.baseDir}/worker";
          description = "Worker state directory.";
        };

        jobType = mkOption {
          type = str;
          default = "vacuum,volume_balance,erasure_coding,admin_script";
          description = "Worker job type list.";
        };

        heartbeat = mkOption {
          type = str;
          default = "15s";
          description = "Worker heartbeat interval.";
        };

        reconnect = mkOption {
          type = str;
          default = "5s";
          description = "Worker reconnect delay.";
        };

        maxDetect = mkOption {
          type = ints.positive;
          default = 1;
          description = "Max concurrent detect requests.";
        };

        maxExecute = mkOption {
          type = ints.positive;
          default = 4;
          description = "Max concurrent execute requests.";
        };

        address = mkOption {
          type = nullOr str;
          default = null;
          description = "Worker advertised address override.";
        };
      };
  };

  config = mkIf swLib.isEnabled {
    assertions = [
      {
        assertion = !cfg.volume.enable || cfg.volume.master != [ ];
        message = "services.seaweedfs.volume.master must not be empty when volume service is enabled.";
      }
      {
        assertion = !cfg.filer.enable || cfg.filer.master != [ ];
        message = "services.seaweedfs.filer.master must not be empty when filer service is enabled.";
      }
      {
        assertion = !cfg.admin.enable || cfg.admin.master != [ ];
        message = "services.seaweedfs.admin.master must not be empty when admin service is enabled.";
      }
      {
        assertion = !cfg.worker.enable || cfg.worker.admin != "";
        message = "services.seaweedfs.worker.admin must not be empty when worker service is enabled.";
      }
    ];
  };
}
