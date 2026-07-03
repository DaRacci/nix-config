{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    types
    splitString
    attrByPath
    isAttrs
    filterEmpty
    joinItems
    mkIf
    mkOption
    mkEnableOption
    ;
  inherit (types)
    str
    nullOr
    ;

  #region Helper functions for working with the server cluster
  isIOPrimaryHost =
    value:
    let
      cmp = if isAttrs value then value.host.name else value;
    in
    config.server.ioPrimaryHost == cmp;

  isThisIOPrimaryHost = isIOPrimaryHost config;

  isMonitoringPrimaryHost =
    value:
    let
      cmp = if isAttrs value then value.host.name else value;
    in
    config.server.monitoringPrimaryHost == cmp;

  isThisMonitoringPrimaryHost = isMonitoringPrimaryHost config;

  scenarioNodes =
    let
      nodes = lib.attrByPath [ "_module" "args" "nodes" ] null config;
      _checkNodes =
        assertion:
        builtins.trace "[SERVER_DEBUG] host=${config.host.name or "?"} nodesState=${if nodes != null then "SCENARIO(n=${builtins.toString (builtins.attrNames nodes)}" else "PRODUCTION"}" assertion;
    in
    if nodes != null then _checkNodes nodes else _checkNodes null;

  primaryIOHostConfig =
    if isThisIOPrimaryHost then
      config
    else if scenarioNodes != null then
      scenarioNodes.${config.server.ioPrimaryHost}.config
    else
      self.nixosConfigurations.${config.server.ioPrimaryHost}.config;

  getIOPrimaryHostAttr = attrPath: attrByPath (splitString "." attrPath) null primaryIOHostConfig;

  serverConfigurations =
    (
      if scenarioNodes != null then
        scenarioNodes |> builtins.attrValues |> map (node: node.config)
      else
        builtins.attrValues self.nixosConfigurations |> map (host: host.config)
    )
    |> builtins.filter (cfg: cfg.host.device.role == "server");

  /*
    Get attributes from all server configurations.
    All empty values (null, empty lists, empty attrsets) are filtered out.
  */
  getAllAttrs =
    attrPath:
    serverConfigurations |> map (cfg: attrByPath (splitString "." attrPath) null cfg) |> filterEmpty;

  /*
    Same as `getAllAttrs` but with a function that is applied to each value before returning.

    This function takes two arguments: the attribute value and the server configuration it was taken from.
    If the function returns null, an empty list or an empty attrset, the value will be filtered out.
  */
  getAllAttrsFunc =
    attrPath: func:
    serverConfigurations
    |> map (
      cfg:
      let
        val = attrByPath (splitString "." attrPath) null cfg;
      in
      if val == null then null else func val cfg
    )
    |> filterEmpty;

  /*
    Get attributes from all servers except the current one.
    See `getAllAttrs` for details.
  */
  getOtherAttrs =
    attrPath:
    serverConfigurations
    |> builtins.filter (cfg: cfg.host.name != config.host.name)
    |> map (cfg: attrByPath (splitString "." attrPath) null cfg)
    |> filterEmpty;

  /*
    Same as `getOtherAttrs` but with a function that is applied to each value before returning.
    See `getAllAttrsFunc` for details.
  */
  getOtherAttrsFunc =
    attrPath: func:
    serverConfigurations
    |> builtins.filter (cfg: cfg.host.name != config.host.name)
    |> map (cfg: func (attrByPath (splitString "." attrPath) null cfg) cfg)
    |> filterEmpty;

  /*
    Collect attributes from all server configurations.
    All empty values (null, empty lists, empty attrsets) are filtered out.

    If the result is an attribute set it will be merged into a single attribute set,
    however if there are conflicting keys in the attribute sets an error will be thrown.
  */
  collectAllAttrs = attrPath: getAllAttrs attrPath |> joinItems;

  /*
    Same as `collectAllAttrs` but with a function that is applied to each value before collecting.

    This function takes two arguments: the attribute value and the server configuration it was taken from.
    If the function returns null, an empty list or an empty attrset, the value is filtered out.
  */
  collectAllAttrsFunc = attrPath: func: getAllAttrsFunc attrPath func |> joinItems;

  /*
    Collect attributes from all servers except the current one.
    See `collectAllAttrs` for details.
  */
  collectOtherAttrs = attrPath: getOtherAttrs attrPath |> joinItems;

  /*
    Same as `collectOtherAttrs` but with a function that is applied to each value before collecting.
    See `collectAllAttrsFunc` for details.
  */
  collectOtherAttrsFunc = attrPath: func: getOtherAttrsFunc attrPath func |> joinItems;

  # Returns a list of server hostnames where the function returns true.
  getOthersWhere =
    func:
    serverConfigurations
    |> builtins.filter (cfg: !(isIOPrimaryHost cfg))
    |> builtins.filter func
    |> map (cfg: cfg.host.name);
  #endregion

  # Journald configuration limits — defined once to prevent drift between
  # the daemon config (extraConfig) and the activation vacuum script.
  journalMaxUse = "256M";
  # 1/8 of SystemMaxUse so journald can retain ~7 rotated files at a time.
  # Setting SystemMaxFileSize equal to SystemMaxUse prevents rotation entirely.
  journalMaxFileSize = "32M";
  journalKeepFree = "512M";
  journalRetentionSec = "7day";
  # Slightly under SystemMaxUse so the activation vacuum doesn't fight
  # journald's runtime limit when new logs arrive immediately after cleanup.
  journalVacuumSize = "250M";

  importModule =
    path: inherits:
    import path (
      {
        inherit
          isIOPrimaryHost
          isThisIOPrimaryHost
          isMonitoringPrimaryHost
          isThisMonitoringPrimaryHost
          primaryIOHostConfig
          getIOPrimaryHostAttr

          getAllAttrs
          getAllAttrsFunc
          getOtherAttrs
          getOtherAttrsFunc
          collectAllAttrs
          collectAllAttrsFunc
          collectOtherAttrs
          collectOtherAttrsFunc
          getOthersWhere

          serverConfigurations

          importModule
          ;
      }
      // inherits
    );
in
{
  imports = [
    (importModule ./database { })
    (importModule ./dashboard.nix { })
    (importModule ./monitoring { })
    (importModule ./network.nix { })
    (importModule ./proxy { })

    ./ssh-shell
    ./storage
    ./distributed-builds.nix
    ./tests.nix
  ];

  options.server = {
    enable = mkEnableOption "enable the server module";

    ioPrimaryHost = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Which host is the primary coordinator for IO in the cluster.

        This host will run the primary instances of databases,
        Operate the reverse proxy for handling incoming traffic,
        and will run the MinIO distributed storage cluster's master node.
      '';
    };

    monitoringPrimaryHost = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Which host is the primary collector for monitoring in the cluster.

        This host will run Prometheus, Loki, Grafana, and Alertmanager
        for centralized observability of the entire server cluster.
      '';
    };
  };

  config = mkIf config.server.enable {
    services.journald = {
      storage = "persistent";
      extraConfig = ''
        SystemMaxUse=${journalMaxUse}
        SystemMaxFileSize=${journalMaxFileSize}
        SystemKeepFree=${journalKeepFree}
        MaxRetentionSec=${journalRetentionSec}
      '';
    };

    # Vacuum existing journals on activation so the limits take effect immediately.
    # Without this, journald only enforces SystemMaxUse/SystemMaxFileSize/MaxRetentionSec
    # as new logs are written — existing oversized files are left untouched.
    system.activationScripts.journald-vacuum = lib.mkAfter ''
      ${pkgs.systemd}/bin/journalctl --vacuum-size=${journalVacuumSize} --vacuum-time=${journalRetentionSec} 2>&1 | ${pkgs.coreutils}/bin/cat
    '';

    system.preSwitchChecks.reportChanges = ''
      if [ "$2" == "test" ]; then
        newGenPath="$1"
        oldGenPath=$(readlink /run/current-system)
        if [ ! -z "''${oldGenPath:-}" ]; then
          ${lib.getExe pkgs.dix} "$oldGenPath" "$newGenPath"
        fi
      fi;
    '';
  };
}
