{ lib }:
let
  inherit (lib)
    concatMap
    filterAttrs
    mapAttrsToList
    mkOption
    ;
  inherit (lib.types)
    attrsOf
    listOf
    nullOr
    oneOf
    str
    submodule
    ;

  helpers = import ./lib.nix { inherit lib; };

  secretType = submodule {
    options.secret = mkOption {
      type = str;
      description = "Absolute path to a file the reconciler reads at run time.";
    };
  };

  envValueType = oneOf [
    str
    secretType
  ];
in
{
  options.env = {
    "inherit" = mkOption {
      type = nullOr (listOf str);
      default = null;
      description = "Keys copied from the container's own `$HERMES_HOME/.env`. `null` means the layer declares none; a declared list replaces the inherited one.";
    };

    set = mkOption {
      type = attrsOf envValueType;
      default = { };
      description = "Values written for this profile only: a literal, or `{ secret = <path>; }` read at reconcile time.";
    };

    unset = mkOption {
      type = listOf str;
      default = [ ];
      description = "Keys or globs that must end up absent from `.env`.";
    };

    keep = mkOption {
      type = listOf str;
      default = [ ];
      description = "Exempts a key from an `unset` rule declared by a higher layer.";
    };
  };

  lockOptions = {
    env = mkOption {
      type = listOf str;
      default = [ ];
      description = "Env keys a runtime override may not change.";
    };
  };

  compile = layer: {
    env = {
      inherit (layer.env) set unset keep;
      inherit (layer.env) "inherit";
    };
    lock = {
      inherit (layer.lock) env;
    };
  };

  secretLiterals =
    cfg:
    concatMap (
      layer:
      mapAttrsToList (key: value: "${key}=${value}") (
        filterAttrs (
          _: value: builtins.isString value && lib.mine.strings.looksLikeCredential value
        ) layer.env.set
      )
    ) (helpers.allLayers cfg);
}
