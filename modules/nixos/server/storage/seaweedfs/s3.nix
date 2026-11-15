{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatMap
    concatMapStrings
    concatStringsSep
    getExe
    intersectLists
    listToAttrs
    mapAttrsToList
    mkIf
    mkOption
    optionals
    optionalAttrs
    optionalString
    removeAttrs
    toJSON
    ;

  inherit (lib.types)
    attrs
    attrsOf
    bool
    ints
    listOf
    nullOr
    path
    port
    str
    submodule
    ;

  swLib = import ./lib.nix {
    inherit config lib;
  };

  cfg = config.services.seaweedfs;
  s3 = cfg.filer.s3;

  identityNames = builtins.attrNames s3.identities;
  bucketNames = builtins.attrNames s3.buckets;

  unknownPolicies = builtins.filter (policy: !(builtins.hasAttr policy s3.policies)) (
    concatMap (name: s3.identities.${name}.policies) identityNames
  );

  unknownBucketOwners = builtins.filter (
    name: !(builtins.hasAttr s3.buckets.${name}.owner s3.identities)
  ) bucketNames;

  invalidBucketNames = builtins.filter (
    name:
    !(
      builtins.match "[a-z0-9][a-z0-9.-]*[a-z0-9]" name != null
      && builtins.stringLength name >= 3
      && builtins.stringLength name <= 63
    )
  ) bucketNames;

  suspendedLockedBuckets = builtins.filter (
    name:
    let
      bucket = s3.buckets.${name};
    in
    bucket.withLock && bucket.versioning == "Suspended"
  ) bucketNames;

  # The filer expands `${VAR}` references in credentials against its own environment.
  mkCredential = identity: {
    accessKey =
      if identity.accessKey != null then identity.accessKey else "\${${identity.accessKeyEnv}}";
    secretKey =
      if identity.secretKey != null then identity.secretKey else "\${${identity.secretKeyEnv}}";
  };

  renderedIdentities = mapAttrsToList (
    name: identity:
    {
      inherit name;
      credentials = [ (mkCredential identity) ];
      policy_names = identity.policies;
    }
    // optionalAttrs identity.disabled { disabled = true; }
  ) s3.identities;

  renderedPolicies = mapAttrsToList (name: document: {
    inherit name;
    content = toJSON document;
  }) s3.policies;

  # Entries in the freeform document are appended to the generated ones.
  # Duplicate names would silently shadow each other, so they are rejected instead.
  freeformIdentities = s3.config.identities or [ ];
  freeformPolicies = s3.config.policies or [ ];

  duplicateIdentityNames = intersectLists (map (entry: entry.name or "") renderedIdentities) (
    map (entry: entry.name or "") freeformIdentities
  );

  duplicatePolicyNames = intersectLists (map (entry: entry.name or "") renderedPolicies) (
    map (entry: entry.name or "") freeformPolicies
  );

  identities = renderedIdentities ++ freeformIdentities;
  policies = renderedPolicies ++ freeformPolicies;

  document =
    removeAttrs s3.config [
      "identities"
      "policies"
    ]
    // optionalAttrs (identities != [ ]) { inherit identities; }
    // optionalAttrs (policies != [ ]) { inherit policies; };

  renderedConfig = pkgs.writeText "seaweedfs-s3.json" (toJSON document);

  envRefs = concatMap (
    name:
    let
      identity = s3.identities.${name};
    in
    optionals (identity.accessKey == null) [
      {
        env = identity.accessKeyEnv;
        secret = identity.accessKeySecret;
      }
    ]
    ++ optionals (identity.secretKey == null) [
      {
        env = identity.secretKeyEnv;
        secret = identity.secretKeySecret;
      }
    ]
  ) identityNames;

  secretOptions = {
    owner = "seaweedfs";
    group = "seaweedfs";
    mode = "0400";
    restartUnits = [ "seaweedfs-filer.service" ];
  };

  hasEnvRefs = envRefs != [ ];

  bucketCommands = concatStringsSep "\n" (
    concatMap (
      name:
      let
        bucket = s3.buckets.${name};
      in
      [
        "s3.bucket.create -name ${name} -owner ${bucket.owner}${optionalString bucket.withLock " -withLock"}"
      ]
      ++ optionals (bucket.versioning != null) [
        "s3.bucket.versioning -name ${name} -status ${bucket.versioning}"
      ]
      ++ optionals (bucket.quotaMB != null) [
        "s3.bucket.quota -name ${name} -op=set -sizeMB=${toString bucket.quotaMB}"
      ]
    ) bucketNames
  );
in
{
  options.services.seaweedfs.filer.s3 = swLib.mkComponentOptions {
    name = "s3";
    httpPort = 8333;
    grpcPortNullable = true;
    ip = null;
    ipBind = false;
    metricsPort = false;
    extraOptions = {
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
          Setting any identity renders `services.seaweedfs.filer.s3.config` from these options,
          so a manual `services.seaweedfs.filer.s3.config` and this option are mutually exclusive.
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
  };

  config = mkIf (swLib.isEnabled && s3.enable) {
    assertions = [
      {
        assertion = unknownPolicies == [ ];
        message = "services.seaweedfs.filer.s3.identities reference unknown policies: ${lib.concatStringsSep ", " unknownPolicies}";
      }
      {
        assertion = duplicateIdentityNames == [ ];
        message = "S3 identity names are declared twice, once in `identities` and once in `config.identities`: ${lib.concatStringsSep ", " duplicateIdentityNames}";
      }
      {
        assertion = duplicatePolicyNames == [ ];
        message = "S3 policy names are declared twice, once in `policies` and once in `config.policies`: ${lib.concatStringsSep ", " duplicatePolicyNames}";
      }
      {
        assertion = unknownBucketOwners == [ ];
        message = "services.seaweedfs.filer.s3.buckets.<name>.owner must name a configured identity: ${lib.concatStringsSep ", " unknownBucketOwners}";
      }
      {
        assertion = invalidBucketNames == [ ];
        message = "services.seaweedfs.filer.s3.buckets keys must be valid S3 bucket names: ${lib.concatStringsSep ", " invalidBucketNames}";
      }
      {
        assertion = suspendedLockedBuckets == [ ];
        message = "Object Lock does not allow suspending versioning: ${lib.concatStringsSep ", " suspendedLockedBuckets}";
      }
    ];

    services.seaweedfs.filer.s3.configFile = mkIf (document != { }) renderedConfig;

    sops.secrets = mkIf (identityNames != [ ]) (
      listToAttrs (
        map (ref: {
          name = ref.secret;
          value = secretOptions;
        }) envRefs
      )
    );

    sops.templates = mkIf hasEnvRefs {
      "S3/ENV" = {
        owner = "seaweedfs";
        group = "seaweedfs";
        mode = "0400";
        content = concatMapStrings (ref: "${ref.env}=${config.sops.placeholder.${ref.secret}}\n") envRefs;
      };
    };

    systemd.services.seaweedfs-filer.serviceConfig.EnvironmentFile = mkIf hasEnvRefs [
      config.sops.templates."S3/ENV".path
    ];

    systemd.services.seaweedfs-s3-init =
      mkIf (bucketNames != [ ] && cfg.master.enable && cfg.filer.enable)
        {
          description = "Create SeaweedFS S3 buckets";
          wantedBy = [ "multi-user.target" ];
          after = [
            "seaweedfs-master.service"
            "seaweedfs-filer.service"
          ];
          requires = [
            "seaweedfs-master.service"
            "seaweedfs-filer.service"
          ];
          script = ''
            status=0
            output=$(
              ${getExe cfg.package} shell -master=127.0.0.1:${toString cfg.master.port} <<'EOF' 2>&1
            ${bucketCommands}
            EOF
            ) || status=$?

            # Every command runs even when an earlier one fails, so an existing bucket
            # does not hide a real failure for the ones after it.
            unexpected=$(printf '%s\n' "$output" | grep '^error:' | grep -v 'already exists' || true)

            if [ -n "$unexpected" ] || { [ "$status" -ne 0 ] && ! printf '%s\n' "$output" | grep -q 'already exists'; }; then
              printf '%s\n' "$output" >&2
              exit 1
            fi
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "seaweedfs";
            Group = "seaweedfs";
            WorkingDirectory = cfg.master.dataDir;
            LimitNOFILE = 65535;
          };
        };
  };
}
