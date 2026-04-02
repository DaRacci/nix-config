{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkMerge
    mkIf
    mkDefault
    types
    literalExpression
    concatStringsSep
    ;
  inherit (types)
    attrsOf
    str
    enum
    lines
    listOf
    ints
    package
    ;

  cfg = config.services.woodpeckerNix;
  stateDir = cfg.stateDir;
  cacheDir = "${stateDir}/cache";

  runtimeEnv = pkgs.buildEnv {
    name = "woodpecker-ci-runtime";
    paths = [ cfg.isolatedStore.package ] ++ cfg.isolatedStore.runtimePackages;
    pathsToLink = [
      "/bin"
      "/etc"
      "/share"
      "/lib"
    ];
  };

  allBootstrapPkgs = [ runtimeEnv ] ++ cfg.isolatedStore.bootstrapPackages;

  bootstrapHash = builtins.hashString "sha256" (
    concatStringsSep " " (map (p: builtins.unsafeDiscardStringContext (toString p)) allBootstrapPkgs)
  );

  nixConf = ''
    build-users-group =
    trusted-users = root *
    allowed-users = *
    substituters = ${concatStringsSep " " cfg.isolatedStore.substituters}
    trusted-public-keys = ${concatStringsSep " " cfg.isolatedStore.trustedPublicKeys}
    sandbox = false
    keep-outputs = true
    keep-derivations = true
    max-jobs = ${toString cfg.isolatedStore.maxJobs}
    experimental-features = nix-command flakes
    ${cfg.isolatedStore.extraConfig}
  '';
in
{
  options.services.woodpeckerNix = {
    enable = mkEnableOption "specialised Nix configuration for Woodpecker CI pipelines";

    stateDir = mkOption {
      type = str;
      default = "/var/lib/woodpecker-nix";
      description = ''
        Directory that holds the isolated Nix store, daemon socket, and config.
      '';
    };

    isolatedStore = {
      enable = mkEnableOption "Whether to set up an isolated Nix store and daemon";

      runtimePackages = mkOption {
        type = listOf package;
        default = with pkgs; [
          bashInteractive
          coreutils-full
          cacert
          gitMinimal
          gnutar
          gzip
          gnugrep
          findutils
          curl
        ];
        defaultText = literalExpression ''
          with pkgs; [
            bashInteractive coreutils-full cacert gitMinimal
            gnutar gzip gnugrep findutils curl
          ]
        '';
        description = ''
          Packages whose closures are copied into the CI store **and** whose
          `bin/` directories are exposed to pipeline containers via `PATH`.

          The module creates a merged `buildEnv` from these packages plus
          {option}`package` (the Nix/Lix daemon) and injects `PATH`,
          `SSL_CERT_FILE`, and related variables pointing into that env.
        '';
      };

      bootstrapPackages = mkOption {
        type = listOf package;
        default = [ ];
        example = literalExpression "[ pkgs.hello ]";
        description = ''
          Extra packages whose closures are copied into the CI store during
          initialisation but are **not** added to `PATH`.
        '';
      };

      package = mkOption {
        type = package;
        default = config.nix.package;
        defaultText = literalExpression "config.nix.package";
        description = ''
          The Nix package to run inside the isolated daemon.
          Always included in the runtime environment.
        '';
      };

      maxJobs = mkOption {
        type = ints.unsigned;
        default = 8;
        description = "Maximum number of parallel builds the isolated daemon may run.";
      };

      substituters = mkOption {
        type = listOf str;
        default = [ ];
        description = ''
          Binary-cache substituters for the isolated daemon.
          When left empty the host's substituters are inherited automatically.
        '';
      };

      trustedPublicKeys = mkOption {
        type = listOf str;
        default = [ ];
        description = ''
          Trusted public keys that correspond to the configured substituters.
          When left empty the host's keys are inherited automatically.
        '';
      };

      extraConfig = mkOption {
        type = lines;
        default = "";
        description = "Extra lines appended verbatim to the isolated daemon's nix.conf.";
      };

      gc = {
        enable = mkEnableOption "Whether to set up periodic garbage collection for the isolated store" // {
          default = true;
        };

        interval = mkOption {
          type = str;
          default = "weekly";
          description = "systemd calendar expression for the GC timer.";
        };

        olderThan = mkOption {
          type = str;
          default = "14d";
          description = "Delete store paths older than this threshold.";
        };
      };
    };

    cache = mkOption {
      type = enum [
        "none"
        "git"
        "all"
      ];
      default = "git";
      description = ''
        Level of caching to share with Woodpecker CI pipelines.

        Options:
          * none:
            Don't share any caches. Each pipeline starts with an empty cache directory.
            This will result in a significant slowdown for pipelines while they unpack
            and populate flake inputs into the git cache.

          * git:
            Share the Nix git fetch cache (gitv3) across pipeline containers.
            Mounted at `/root/.cache/nix/gitv3` inside each container.

          * all:
            Share the Nix eval cache across pipeline containers.

            The eval cache is a SQLite database and concurrent writes from
            parallel jobs can cause lock contention.
            Safe to enable when `WOODPECKER_MAX_WORKFLOWS=1`.

            When enabled the entire cache directory is mounted at
            `/root/.cache/nix` (which also covers the git cache).
      '';
    };

    woodpecker = {
      agents = mkOption {
        type = listOf str;
        default = [ ];
        description = ''
          Names of Woodpecker agents to configure with the shared Nix store.
          Must match the attribute names under `services.woodpecker-agents.agents`.
        '';
      };

      extraVolumes = mkOption {
        type = listOf str;
        default = [ ];
        description = ''
          Additional Docker volume specifications appended to
          `WOODPECKER_BACKEND_DOCKER_VOLUMES`.
        '';
      };

      extraEnvironment = mkOption {
        type = attrsOf str;
        default = { };
        description = ''
          Additional entries appended to `WOODPECKER_ENVIRONMENT`.
        '';
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable && cfg.cache != "none") (
      let
        inherit
          (
            if cfg.cache == "git" then
              {
                hostPath = "${cacheDir}/gitv3";
                containerPath = "/root/.cache/nix/gitv3";
              }
            else if cfg.cache == "all" then
              {
                hostPath = cacheDir;
                containerPath = "/root/.cache/nix";
              }
            else
              {
                hostPath = null;
                containerPath = null;
              }
          )
          hostPath
          containerPath
          ;
      in
      {
        services.woodpeckerNix.woodpecker.extraVolumes = [ "${hostPath}:${containerPath}" ];
        systemd.tmpfiles.settings."woodpecker-nix"."${cacheDir}".d = {
          mode = "1777";
        };
      }
    ))

    (mkIf (cfg.enable && cfg.isolatedStore.enable) {
      services.woodpeckerNix = {
        isolatedStore = {
          substituters = mkDefault config.nix.settings.substituters;
          trustedPublicKeys = mkDefault config.nix.settings.trusted-public-keys;
        };

        woodpecker = {
          extraVolumes = [
            "${stateDir}/nix/store:/nix/store"
            "${stateDir}/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket"
            "${stateDir}/nix/var/nix/profiles:/nix/var/nix/profiles"
          ];
          extraEnvironment =
            let
              sslCertPath = "${runtimeEnv}/etc/ssl/certs/ca-bundle.crt";
            in
            {
              NIX_REMOTE = "daemon";
              PATH = "${runtimeEnv}/bin:/bin:/usr/bin";
              SSL_CERT_FILE = sslCertPath;
              NIX_SSL_CERT_FILE = sslCertPath;
              GIT_SSL_CAINFO = sslCertPath;
            };
        };
      };

      systemd = {
        tmpfiles.settings."woodpecker-nix" = {
          "${stateDir}/etc/nix/nix.conf"."f+" = {
            mode = "0644";
            argument = nixConf;
          };
        }
        // (
          [
            "${stateDir}/etc/nix"
            "${stateDir}/nix/var/nix/daemon-socket"
            "${stateDir}/nix/var/nix/db"
            "${stateDir}/nix/var/nix/profiles"
            "${stateDir}/nix/var/nix/gcroots"
          ]
          |> map (p: lib.nameValuePair p { d.mode = "1777"; })
          |> lib.listToAttrs
        );

        services = {
          woodpecker-nix-init = {
            description = "Bootstrap isolated Nix store for Woodpecker CI";
            requiredBy = [ "woodpecker-nix-daemon.service" ];
            before = [ "woodpecker-nix-daemon.service" ];
            after = [ "local-fs.target" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };

            path = [
              cfg.isolatedStore.package
              pkgs.uutils-coreutils-noprefix
            ];

            script =
              let
                bootstrapStorePaths = concatStringsSep " " (map (p: ''"${p}"'') allBootstrapPkgs);
              in
              ''
                set -euo pipefail

                CURRENT_HASH="${bootstrapHash}"
                HASH_FILE="${stateDir}/.bootstrap-hash"

                if [ -f "$HASH_FILE" ] && [ "$(cat "$HASH_FILE")" = "$CURRENT_HASH" ]; then
                  echo "==> Store is up-to-date (hash: $CURRENT_HASH). Verifying profiles ..."
                else
                  echo "==> Bootstrapping CI Nix store at ${stateDir} ..."

                  for pkg in ${bootstrapStorePaths}; do
                    echo "    Copying closure: $pkg ..."
                    nix copy \
                      --no-check-sigs \
                      --to "local?root=${stateDir}" \
                      "$pkg"
                  done

                  printf '%s' "$CURRENT_HASH" > "$HASH_FILE"
                  echo "==> Store bootstrap complete (hash: $CURRENT_HASH)."
                fi

                echo "==> Reconstructing profile symlinks ..."
                ln -sfn ${runtimeEnv} "${stateDir}/nix/var/nix/profiles/default-1-link"
                ln -sfn /nix/var/nix/profiles/default-1-link "${stateDir}/nix/var/nix/profiles/default"

                mkdir -p "${stateDir}/nix/var/nix/profiles/per-user/root"

                echo "==> Registering GC roots ..."
                ln -sfn ${runtimeEnv} "${stateDir}/nix/var/nix/gcroots/runtime-env"

                echo "==> Init complete."
              '';
          };

          woodpecker-nix-daemon = {
            description = "Woodpecker CI Shared Nix Store Daemon";
            wantedBy = [ "multi-user.target" ];
            after = [
              "woodpecker-nix-init.service"
              "network-online.target"
            ];
            wants = [ "network-online.target" ];
            requires = [ "woodpecker-nix-init.service" ];

            serviceConfig = {
              Type = "simple";
              ExecStart = "${cfg.isolatedStore.package}/bin/nix daemon";
              Environment = "NIX_CONF_DIR=${stateDir}/etc/nix";
              BindPaths = [ "${stateDir}/nix:/nix" ];
              ReadWritePaths = [ stateDir ];

              PrivateMounts = true;
              PrivateTmp = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              PrivateDevices = true;
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
              ProtectControlGroups = true;
              NoNewPrivileges = true;
              RestrictSUIDSGID = true;

              LimitNOFILE = 65536;
              Restart = "on-failure";
              RestartSec = "5s";
              TimeoutStartSec = "120";
              KillMode = "mixed";
            };
          };
        };
      };
    })

    (mkIf (cfg.enable && cfg.isolatedStore.enable && cfg.isolatedStore.gc.enable) {
      systemd = {
        services.woodpecker-nix-gc = {
          description = "Garbage-collect the Woodpecker CI shared Nix store";
          after = [ "woodpecker-nix-daemon.service" ];
          requires = [ "woodpecker-nix-daemon.service" ];

          serviceConfig.Type = "oneshot";

          script = ''
            export NIX_REMOTE="unix://${stateDir}/nix/var/nix/daemon-socket/socket"
            ${cfg.isolatedStore.package}/bin/nix-collect-garbage \
              --delete-older-than "${cfg.isolatedStore.gc.olderThan}"
          '';
        };

        timers.woodpecker-nix-gc = {
          description = "Periodically garbage-collect the Woodpecker CI shared Nix store";
          wantedBy = [ "timers.target" ];
          after = [ "woodpecker-nix-daemon.service" ];
          requires = [ "woodpecker-nix-daemon.service" ];

          timerConfig = {
            OnCalendar = cfg.isolatedStore.gc.interval;
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };
      };
    })

    (mkIf (cfg.enable && cfg.woodpecker.agents != [ ]) {
      services.woodpecker-agents.agents =
        let
          agentCfg = {
            environment = {
              WOODPECKER_BACKEND_DOCKER_VOLUMES = mkDefault (concatStringsSep "," cfg.woodpecker.extraVolumes);
              WOODPECKER_ENVIRONMENT = mkDefault (
                lib.mapAttrsToList (k: v: "${k}:${v}") cfg.woodpecker.extraEnvironment |> concatStringsSep ","
              );
            };
          };
        in
        lib.genAttrs cfg.woodpecker.agents (_name: agentCfg);
    })
  ];
}
