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
    optionalString
    optional
    ;
  inherit (types)
    attrsOf
    str
    enum
    lines
    listOf
    nullOr
    ints
    package
    ;

  cfg = config.services.woodpeckerNix;
  stateDir = cfg.stateDir;
  cacheDir = "${stateDir}/cache";

  storeRealDir = "${stateDir}/nix/store-real";
  overlayDir = "${stateDir}/nix/overlay";
  upperDir = "${overlayDir}/upper";
  workDir = "${overlayDir}/work";

  gcSizeThreshold = cfg.isolatedStore.gc.sizeThreshold;
  propagationInterval = cfg.isolatedStore.propagation.interval;

  overlayEnabled = cfg.isolatedStore.overlayfs.enable;

  storeSizeBytes = lib.mine.strings.parseSize gcSizeThreshold;

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

  nixBuildUsersGroup = "woodpecker-nix-build-users";
  nixConf = ''
    build-users-group = ${nixBuildUsersGroup}
    allowed-users = *
    substituters = ${concatStringsSep " " cfg.isolatedStore.substituters}
    trusted-public-keys = ${concatStringsSep " " cfg.isolatedStore.trustedPublicKeys}
    require-sigs = true
    sandbox = true
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

      overlayfs = {
        enable = mkEnableOption "Whether to use overlayfs for the isolated Nix store" // {
          default = true;
        };

        upperDir = mkOption {
          type = str;
          default = "${stateDir}/nix/overlay/upper";
          defaultText = literalExpression "\${stateDir}/nix/overlay/upper";
          description = ''
            Path for the overlayfs upper (writable) layer.
            New store paths from container builds land here.
          '';
        };

        workDir = mkOption {
          type = str;
          default = "${stateDir}/nix/overlay/work";
          defaultText = literalExpression "\${stateDir}/nix/overlay/work";
          description = ''
            Path for the overlayfs work directory.
            Required by overlayfs; not used for storage.
          '';
        };
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

        sizeThreshold = mkOption {
          type = str;
          default = "20G";
          description = ''
            Minimum store size before GC is triggered.
            Prevents unnecessary GC when the store is small.
            Accepts units: K, Ki, M, Mi, G, Gi, T, Ti.
          '';
        };

        minInterval = mkOption {
          type = str;
          default = "7d";
          description = ''
            Minimum time between GC runs.
            Prevents GC thrashing when the store hovers near the size threshold.
          '';
        };

        maxFreed = mkOption {
          type = nullOr str;
          default = null;
          description = ''
            Maximum amount of data to free in a single GC run.
            Prevents overly aggressive collection.
          '';
        };
      };

      propagation = {
        enable = mkEnableOption "Whether to run a propagation sidecar that audits new store paths" // {
          default = true;
        };

        interval = mkOption {
          type = str;
          default = "15m";
          description = "systemd calendar expression for the propagation audit timer.";
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
          mode = "0700";
          user = "woodpecker-nix";
          group = nixBuildUsersGroup;
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
            "${stateDir}/nix:/nix"
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
          |> map (p: lib.nameValuePair p { d.mode = "0700"; })
          |> lib.listToAttrs
        )
        // (mkIf overlayEnabled {
          "${storeRealDir}".d = {
            mode = "0700";
          };
          "${upperDir}".d = {
            mode = "0700";
          };
          "${workDir}".d = {
            mode = "0700";
          };
        });

        services = {
          woodpecker-nix-init = {
            description = "Bootstrap isolated Nix store for Woodpecker CI";
            requiredBy = [ "woodpecker-nix-daemon.service" ];
            before = [ "woodpecker-nix-daemon.service" ];
            after = [ "local-fs.target" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;

              NoNewPrivileges = true;
              ProtectClock = true;
              ProtectHostname = true;
              ProtectKernelModules = true;
              ProtectKernelLogs = true;
              ProtectKernelTunables = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              LockPersonality = true;

              PrivateDevices = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              RestrictNamespaces = true;

              CapabilityBoundingSet = "";
              SystemCallFilter = [ "@system-service" ];
              SystemCallArchitectures = "native";
              SystemCallErrorNumber = "EPERM";
              MemoryDenyWriteExecute = true;

              ReadWritePaths = [ stateDir ];
            };

            path = [
              cfg.isolatedStore.package
              pkgs.uutils-coreutils-noprefix
            ]
            ++ (mkIf overlayEnabled [ pkgs.util-linux ]);

            script =
              let
                bootstrapStorePaths = concatStringsSep " " (map (p: ''"${p}"'') allBootstrapPkgs);
                overlaySetup = optionalString overlayEnabled ''
                  echo ">>> Setting up overlayfs for isolated Nix store ..."

                  mkdir -p "${storeRealDir}"
                  mkdir -p "${upperDir}"
                  mkdir -p "${workDir}"

                  # Move existing store content into store-real (lower layer)
                  if [ -d "${stateDir}/nix/store" ] && [ -z "$(ls -A ${stateDir}/nix/store 2>/dev/null)" ]; then
                    echo "    Fresh install -- store is empty, nothing to move."
                  elif [ -d "${stateDir}/nix/store" ]; then
                    echo "    Moving existing store content to store-real ..."
                    mv "${stateDir}/nix/store"/* "${storeRealDir}/" 2>/dev/null || true
                    rm -rf "${stateDir}/nix/store"
                  fi

                  mount -t overlay overlay -o "lowerdir=${storeRealDir},upperdir=${upperDir},workdir=${workDir}" "${stateDir}/nix/store"

                  echo "    Overlayfs mounted: lower=${storeRealDir}, upper=${upperDir}"
                '';
              in
              ''
                set -euo pipefail

                CURRENT_HASH="${bootstrapHash}"
                HASH_FILE="${stateDir}/.bootstrap-hash"

                if [ -f "$HASH_FILE" ] && [ "$(cat "$HASH_FILE")" = "$CURRENT_HASH" ]; then
                  echo ">>> Store is up-to-date (hash: $CURRENT_HASH). Verifying profiles ..."
                else
                  echo ">>> Bootstrapping CI Nix store at ${stateDir} ..."

                  for pkg in ${bootstrapStorePaths}; do
                    echo "    Copying closure: $pkg ..."
                    nix copy --to "local?root=${stateDir}" "$pkg"
                  done

                  printf '%s' "$CURRENT_HASH" > "$HASH_FILE"
                  echo ">>> Store bootstrap complete (hash: $CURRENT_HASH)."
                fi

                ${overlaySetup}

                echo ">>> Reconstructing profile symlinks ..."
                ln -sfn ${runtimeEnv} "${stateDir}/nix/var/nix/profiles/default-1-link"
                ln -sfn /nix/var/nix/profiles/default-1-link "${stateDir}/nix/var/nix/profiles/default"

                mkdir -p "${stateDir}/nix/var/nix/profiles/per-user/root"

                echo ">>> Registering GC roots ..."
                ln -sfn ${runtimeEnv} "${stateDir}/nix/var/nix/gcroots/runtime-env"

                echo ">>> Init complete."
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
            restartTriggers = [ (pkgs.writeText "woodpecker-nix.conf" nixConf) ];

            serviceConfig = {
              Type = "simple";
              ExecStart = "${cfg.isolatedStore.package}/bin/nix daemon";
              Environment = "NIX_CONF_DIR=${stateDir}/etc/nix";
              BindPaths = [ "${stateDir}/nix:/nix" ];
              StateDirectory = "woodpecker-nix";
              DynamicUser = true;
              Group = nixBuildUsersGroup;
              SupplementaryGroups = [ nixBuildUsersGroup ];
              ReadWritePaths = [ stateDir ];

              NoNewPrivileges = true;
              ProtectClock = true;
              ProtectHostname = true;
              ProtectKernelModules = true;
              ProtectKernelLogs = true;
              ProtectKernelTunables = true;
              ProtectControlGroups = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              LockPersonality = true;

              PrivateDevices = true;
              PrivateMounts = true;
              PrivateTmp = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              RestrictNamespaces = true;

              CapabilityBoundingSet = "";
              RestrictAddressFamilies = [
                "AF_UNIX"
                "AF_INET"
                "AF_INET6"
              ];
              SystemCallFilter = [ "@system-service" ];
              SystemCallArchitectures = "native";
              SystemCallErrorNumber = "EPERM";
              MemoryDenyWriteExecute = true;

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

          serviceConfig = {
            Type = "oneshot";

            DynamicUser = true;
            StateDirectory = "woodpecker-nix-gc";
            Environment = [
              "HOME=/var/lib/woodpecker-nix-gc"
              "XDG_CACHE_HOME=/var/lib/woodpecker-nix-gc/.cache"
              "XDG_CONFIG_HOME=/var/lib/woodpecker-nix-gc/.config"
              "XDG_DATA_HOME=/var/lib/woodpecker-nix-gc/.local/share"
              "STATE_DIR=${stateDir}"
              "STORE_SIZE_FILE=${stateDir}/.store-size"
              "SIZE_THRESHOLD_BYTES=${toString storeSizeBytes}"
              "GC_OLDER_THAN=${cfg.isolatedStore.gc.olderThan}"
              "MIN_INTERVAL=${cfg.isolatedStore.gc.minInterval}"
              "NIX_REMOTE=unix://${stateDir}/nix/var/nix/daemon-socket/socket"
            ]
            ++ (optional cfg.isolatedStore.gc.maxFreed "GC_MAX_FREED=${cfg.isolatedStore.gc.maxFreed}");
            NoNewPrivileges = true;

            ProtectClock = true;
            ProtectHostname = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectKernelTunables = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;

            PrivateDevices = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            RestrictNamespaces = true;

            CapabilityBoundingSet = "";
            RestrictAddressFamilies = [ "AF_UNIX" ];
            SystemCallFilter = [ "@system-service" ];
            SystemCallArchitectures = "native";
            SystemCallErrorNumber = "EPERM";
            MemoryDenyWriteExecute = true;

            ReadWritePaths = [ stateDir ];
          };

          script = ''
            set -euo pipefail

            SIZE_THRESHOLD_BYTES="$SIZE_THRESHOLD_BYTES"
            MIN_INTERVAL="$MIN_INTERVAL"
            LAST_GC_FILE="$STATE_DIR/.last-gc"
            STORE_SIZE_FILE="$STATE_DIR/.store-size"

            # --- Size gate ---
            if [ -f "$STORE_SIZE_FILE" ]; then
              CURRENT_SIZE=$(cat "$STORE_SIZE_FILE")
            else
              CURRENT_SIZE=0
            fi

            SIZE_HUMAN=$(( CURRENT_SIZE / 1024 / 1024 ))
            THRESHOLD_HUMAN=$(( SIZE_THRESHOLD_BYTES / 1024 / 1024 ))

            if [ "$CURRENT_SIZE" -lt "$SIZE_THRESHOLD_BYTES" ]; then
              echo ">>> GC: Store size (''${SIZE_HUMAN}MB) below threshold (''${THRESHOLD_HUMAN}MB). Skipping."
              exit 0
            fi

            # --- Time gate ---
            if [ -f "$LAST_GC_FILE" ]; then
              LAST_GC_EPOCH=$(cat "$LAST_GC_FILE")
              NOW_EPOCH=$(date +%s)
              CUTOFF_EPOCH=$(date -d "$MIN_INTERVAL ago" +%s 2>/dev/null || date -v-''${MIN_INTERVAL} +%s 2>/dev/null || echo 0)
              if [ "$LAST_GC_EPOCH" -gt "$CUTOFF_EPOCH" ]; then
                REMAINING=$(( LAST_GC_EPOCH - CUTOFF_EPOCH ))
                ELAPSED=$(( NOW_EPOCH - LAST_GC_EPOCH ))
                echo ">>> GC: Last GC was ''${ELAPSED}s ago, minimum interval not met (''${REMAINING}s remaining). Skipping."
                exit 0
              fi
            fi

            echo ">>> GC: Store size (''${SIZE_HUMAN}MB) exceeds threshold (''${THRESHOLD_HUMAN}MB). Running GC..."

            export NIX_REMOTE="unix://${stateDir}/nix/var/nix/daemon-socket/socket"
            ${cfg.isolatedStore.package}/bin/nix-collect-garbage \
              --delete-older-than "${cfg.isolatedStore.gc.olderThan}" \
              ${optionalString cfg.isolatedStore.gc.maxFreed ''--max-freed "${cfg.isolatedStore.gc.maxFreed}"''}

            # Record GC timestamp
            date +%s > "$LAST_GC_FILE"

            # Update store size cache after GC
            NEW_SIZE=$(du -sb "$STATE_DIR/nix/store" 2>/dev/null | awk '{print $1}' || echo 0)
            echo "$NEW_SIZE" > "$STORE_SIZE_FILE"

            echo ">>> GC: Complete."
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

    (mkIf (cfg.enable && cfg.isolatedStore.enable && cfg.isolatedStore.propagation.enable) {
      systemd = {
        services.woodpecker-nix-propagate = {
          description = "Audit new store paths in overlayfs upper layer";
          after = [
            "woodpecker-nix-daemon.service"
          ];
          requires = [ "woodpecker-nix-daemon.service" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            StateDirectory = "woodpecker-nix-propagate";
            Environment = [
              "STATE_DIR=${stateDir}"
              "UPPER_DIR=${upperDir}"
              "STORE_REAL_DIR=${storeRealDir}"
              "JOURNAL=${stateDir}/propagation-journal"
              "STORE_SIZE_FILE=${stateDir}/.store-size"
              "NIX_REMOTE=unix://${stateDir}/nix/var/nix/daemon-socket/socket"
            ];
            NoNewPrivileges = true;
            ProtectClock = true;
            ProtectHostname = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectKernelTunables = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            PrivateDevices = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            RestrictNamespaces = true;
            CapabilityBoundingSet = "";
            RestrictAddressFamilies = [ "AF_UNIX" ];
            SystemCallFilter = [ "@system-service" ];
            SystemCallArchitectures = "native";
            SystemCallErrorNumber = "EPERM";
            MemoryDenyWriteExecute = true;
            ReadWritePaths = [ stateDir ];
            ExecStart = pkgs.writeShellScript "woodpecker-nix-propagate" ''
              set -euo pipefail

              STATE_DIR="$STATE_DIR"
              UPPER_DIR="$UPPER_DIR"
              STORE_REAL_DIR="$STORE_REAL_DIR"
              JOURNAL="$JOURNAL"
              STORE_SIZE_FILE="$STORE_SIZE_FILE"
              NIX="${cfg.isolatedStore.package}/bin/nix"

              touch "$JOURNAL"

              log() {
                echo "[$(date -Iseconds)] propagate: $*"
              }

              update_store_size() {
                local size_bytes
                size_bytes=$(du -sb "$STATE_DIR/nix/store" 2>/dev/null | awk '{print $1}' || echo 0)
                echo "$size_bytes" > "$STORE_SIZE_FILE"
                log "Store size: $(( size_bytes / 1024 / 1024 )) MB"
              }

              scan_new_paths() {
                local new_count=0

                if [ ! -d "$UPPER_DIR" ]; then
                  log "No upperdir found at $UPPER_DIR, skipping scan"
                  return 0
                fi

                while IFS= read -r narinfo; do
                  local basename
                  basename=$(basename "$narinfo" .narinfo)
                  local store_path="store-''${basename}"

                  if grep -qF "$store_path" "$JOURNAL" 2>/dev/null; then
                    continue
                  fi

                  local path_size
                  path_size=$(grep -oP 'servedb-size: \K[0-9]+' "$narinfo" 2>/dev/null || echo "0")

                  log "NEW: $store_path (narinfo-size: ''${path_size} bytes)"
                  echo "$(date -Iseconds) $store_path $path_size" >> "$JOURNAL"
                  new_count=$(( new_count + 1 ))
                done < <(find "$UPPER_DIR" -name '*.narinfo' -type f 2>/dev/null)

                while IFS= read -r store_dir; do
                  local dir_name
                  dir_name=$(basename "$store_dir")

                  case "$dir_name" in
                    info|locks|temp|log|db) continue ;;
                  esac

                  if grep -qF "$dir_name" "$JOURNAL" 2>/dev/null; then
                    continue
                  fi

                  if [[ "$dir_name" =~ ^[a-z0-9]{32}-.*$ ]]; then
                    local dir_size
                    dir_size=$(du -sb "$store_dir" 2>/dev/null | awk '{print $1}' || echo "0")
                    log "NEW: $dir_name (dir-size: ''${dir_size} bytes)"
                    echo "$(date -Iseconds) $dir_name $dir_size" >> "$JOURNAL"
                    new_count=$(( new_count + 1 ))
                  fi
                done < <(find "$UPPER_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)

                log "Scan complete: $new_count new paths found"
              }

              log "Propagation sidecar started"
              log "Upper dir: $UPPER_DIR"
              log "Store real dir: $STORE_REAL_DIR"
              log "Journal: $JOURNAL"

              update_store_size
              scan_new_paths

              log "Propagation audit complete. Exiting."
            '';
          };
        };

        timers.woodpecker-nix-propagate = {
          description = "Periodically audit new store paths in overlayfs";
          wantedBy = [ "timers.target" ];
          after = [ "woodpecker-nix-daemon.service" ];
          requires = [ "woodpecker-nix-daemon.service" ];

          timerConfig = {
            OnCalendar = propagationInterval;
            Persistent = true;
            RandomizedDelaySec = "2m";
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
