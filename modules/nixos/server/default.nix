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

  primaryIOHostConfig =
    if isThisIOPrimaryHost then
      config
    else
      self.nixosConfigurations.${config.server.ioPrimaryHost}.config;

  getIOPrimaryHostAttr = attrPath: attrByPath (splitString "." attrPath) null primaryIOHostConfig;

  serverConfigurations =
    builtins.attrValues self.nixosConfigurations
    |> builtins.map (host: host.config)
    |> builtins.filter (cfg: cfg.host.device.role == "server");

  /*
    Get attributes from all server configurations.
    All empty values (null, empty lists, empty attrsets) are filtered out.
  */
  getAllAttrs =
    attrPath:
    serverConfigurations
    |> builtins.map (cfg: attrByPath (splitString "." attrPath) null cfg)
    |> filterEmpty;

  /*
    Same as `getAllAttrs` but with a function that is applied to each value before returning.

    This function takes two arguments: the attribute value and the server configuration it was taken from.
    If the function returns null, an empty list or an empty attrset, the value will be filtered out.
  */
  getAllAttrsFunc =
    attrPath: func:
    serverConfigurations
    |> builtins.map (cfg: func (attrByPath (splitString "." attrPath) null cfg) cfg)
    |> filterEmpty;

  /*
    Get attributes from all servers except the current one.
    See `getAllAttrs` for details.
  */
  getOtherAttrs =
    attrPath:
    serverConfigurations
    |> builtins.filter (cfg: cfg.host.name != config.host.name)
    |> builtins.map (cfg: attrByPath (splitString "." attrPath) null cfg)
    |> filterEmpty;

  /*
    Same as `getOtherAttrs` but with a function that is applied to each value before returning.
    See `getAllAttrsFunc` for details.
  */
  getOtherAttrsFunc =
    attrPath: func:
    serverConfigurations
    |> builtins.filter (cfg: cfg.host.name != config.host.name)
    |> builtins.map (cfg: func (attrByPath (splitString "." attrPath) null cfg) cfg)
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
    |> builtins.map (cfg: cfg.host.name);
  #endregion

  importModule =
    path: inherits:
    import path (
      {
        inherit
          isIOPrimaryHost
          isThisIOPrimaryHost
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
    (importModule ./network.nix { })
    (importModule ./proxy { })

    ./ssh
    ./storage
    ./distributed-builds.nix
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
  };

  config = mkIf config.server.enable {
    services.journald = {
      storage = "persistent";
      extraConfig = ''
        SystemMaxUse=256M
        SystemMaxFileSize=64M
        SystemKeepFree=512M
        MaxRetentionSec=14day
      '';
    };

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
