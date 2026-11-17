{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrNames
    concatMap
    concatStringsSep
    filter
    foldl'
    getExe
    length
    mkEnableOption
    mkIf
    mkOption
    optional
    recursiveUpdate
    unique
    ;
  inherit (lib.types)
    attrsOf
    nullOr
    str
    submodule
    ;
  inherit (builtins) hasAttr;
  inherit (pkgs) docker;

  helpers = import ./profile-sync/lib.nix { inherit lib; };
  settingsArea = import ./profile-sync/settings.nix { inherit lib; };
  envArea = import ./profile-sync/env.nix { inherit lib; };
  linksArea = import ./profile-sync/links.nix { inherit lib; };
  hlib = import ./lib.nix { inherit lib; };

  cfg = config.services.ai-agent.profileSync;
  hermes = config.services.hermes-agent;

  containerName = "hermes-agent";
  hermesHomeInContainer = "/data/.hermes";

  reconciler = pkgs.profile-sync;

  areas = [
    settingsArea
    envArea
  ];

  vocabulary.options =
    settingsArea.options
    // envArea.options
    // {
      lock = settingsArea.lockOptions // envArea.lockOptions;
    };

  compileLayer = layer: foldl' recursiveUpdate { } (map (area: area.compile layer) areas);

  policy = {
    version = 1;
    defaults = compileLayer cfg.defaults;
    classes = builtins.mapAttrs (_: compileLayer) cfg.classes;
    profiles = builtins.mapAttrs (_: compileLayer) cfg.profiles;
    links = linksArea.compile cfg;
  };

  policyJson = builtins.toJSON policy;
  policyFile = pkgs.writeText "hermes-profile-sync-policy.json" policyJson;

  brokenChains = filter (
    name:
    length (helpers.classChain cfg.classes name)
    != length (unique (helpers.classChain cfg.classes name))
  ) (attrNames cfg.classes);

  missingReferences =
    concatMap (
      name:
      optional (
        cfg.profiles.${name}.class != null && !(hasAttr cfg.profiles.${name}.class cfg.classes)
      ) "profiles.${name}.class = ${cfg.profiles.${name}.class}"
    ) (attrNames cfg.profiles)
    ++ concatMap (
      name:
      optional (
        cfg.classes.${name}.inherits != null && !(hasAttr cfg.classes.${name}.inherits cfg.classes)
      ) "classes.${name}.inherits = ${cfg.classes.${name}.inherits}"
    ) (attrNames cfg.classes);

  lockConflicts = concatMap (
    name:
    let
      layers = helpers.layerChain cfg.defaults cfg.classes cfg.profiles.${name};
      settingsLocks = unique (concatMap (layer: layer.lock.settings) layers);
      envLocks = unique (concatMap (layer: layer.lock.env) layers);
    in
    concatMap (
      path:
      optional (
        length (unique (helpers.assignments layers (layer: layer.settings) path)) > 1
      ) "profiles.${name}: lock on ${path}"
    ) settingsLocks
    ++ concatMap (
      key:
      optional (
        length (unique (helpers.assignments layers (layer: layer.env.set) key)) > 1
      ) "profiles.${name}: lock on env ${key}"
    ) envLocks
  ) (attrNames cfg.profiles);

  readinessAttempts = 60;
  readinessIntervalSec = 2;
in
{
  options.services.ai-agent.profileSync = {
    enable = mkEnableOption "reconciling every Hermes profile against this policy";

    interval = mkOption {
      type = str;
      default = "3h";
      description = "How often the timer re-runs the reconciler.";
    };

    defaults = mkOption {
      type = submodule vocabulary;
      default = { };
      description = "The baseline every profile gets.";
    };

    classes = mkOption {
      type = attrsOf (
        submodule (
          { ... }:
          {
            imports = [ vocabulary ];
            options.inherits = mkOption {
              type = nullOr str;
              default = null;
              description = "Another class whose vocabulary this one starts from.";
            };
          }
        )
      );
      default = { };
      description = "Reusable bundles of the same vocabulary.";
    };

    profiles = mkOption {
      type = attrsOf (
        submodule (
          { ... }:
          {
            imports = [ vocabulary ];
            options.class = mkOption {
              type = nullOr str;
              default = null;
              description = "The class this profile belongs to.";
            };
          }
        )
      );
      default = { };
      description = "Per-profile deltas. A profile with no entry here gets `defaults` only, and the run report lists it as undeclared.";
    };

    links = linksArea.options.links;

    policyJSON = mkOption {
      type = str;
      readOnly = true;
      internal = true;
      description = "The compiled manifest, installed verbatim into HERMES_HOME.";
    };
  };

  config = mkIf cfg.enable {
    services.ai-agent.profileSync.policyJSON = policyJson;

    assertions = [
      {
        assertion = hermes.container.enable;
        message = "services.ai-agent.profileSync needs services.hermes-agent.container.enable: the reconciler runs through docker exec.";
      }
      {
        assertion = missingReferences == [ ];
        message = "profileSync names a class that does not exist: ${concatStringsSep ", " missingReferences}";
      }
      {
        assertion = brokenChains == [ ];
        message = "profileSync class inheritance loops: ${concatStringsSep ", " brokenChains}";
      }
      {
        assertion = settingsArea.violations cfg == [ ];
        message = "profileSync must not sync host-owned or generated settings: ${concatStringsSep ", " (settingsArea.violations cfg)}";
      }
      {
        assertion = envArea.secretLiterals cfg == [ ];
        message = "profileSync env.set carries a credential-shaped literal; use { secret = <path>; }: ${concatStringsSep ", " (envArea.secretLiterals cfg)}";
      }
      {
        assertion = lockConflicts == [ ];
        message = "profileSync lock contradiction, a nix layer assigns a locked key twice: ${concatStringsSep ", " lockConflicts}";
      }
      {
        assertion = linksArea.problems cfg == [ ];
        message = "profileSync link problem: ${concatStringsSep "; " (linksArea.problems cfg)}";
      }
    ];

    services.hermes-agent.hermesHomeFiles."state/profile-sync/policy.json" = policyJson;

    systemd.services.hermes-profile-sync = {
      description = "Reconcile Hermes profile config.yaml and .env against the nix policy";

      after = [
        "docker.service"
        "hermes-agent.service"
      ];
      requires = [ "docker.service" ];
      restartTriggers = [ policyFile ];
      path = [ docker ];

      serviceConfig = {
        Type = "oneshot";
        User = hermes.user;
        Group = hermes.group;
        SupplementaryGroups = [ "docker" ];
        PrivateTmp = true;
        TimeoutStartSec = "10min";
        ConditionPathExists = "/var/run/docker.sock";
        ExecStartPre = hlib.waitForHermesExec pkgs {
          user = hermes.user;
          container = containerName;
          attempts = readinessAttempts;
          intervalSec = readinessIntervalSec;
        };
        ExecStart = concatStringsSep " " [
          (getExe docker)
          "exec"
          "-u ${hermes.user}"
          "--env HERMES_HOME=${hermesHomeInContainer}"
          containerName
          (getExe reconciler)
        ];
      };
    };

    systemd.timers.hermes-profile-sync = {
      description = "Periodic Hermes profile reconciliation";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "hermes-profile-sync.service";
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
      };
    };
  };
}
