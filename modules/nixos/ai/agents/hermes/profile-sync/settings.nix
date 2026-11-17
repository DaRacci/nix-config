{ lib }:
let
  inherit (lib)
    concatMap
    filter
    mkOption
    unique
    ;
  inherit (lib.types)
    anything
    attrsOf
    listOf
    str
    ;

  helpers = import ./lib.nix { inherit lib; };
in
{
  options = {
    settings = mkOption {
      type = attrsOf anything;
      default = { };
      description = "Config keys written into the profile's `config.yaml` at dot-path granularity. A key no layer mentions is never touched.";
    };

    settingsUnset = mkOption {
      type = listOf str;
      default = [ ];
      description = "Dot-paths that must end up absent from `config.yaml`; deleting a node removes its whole subtree.";
    };
  };

  lockOptions = {
    settings = mkOption {
      type = listOf str;
      default = [ ];
      description = "Dot-paths a runtime override may not change, plus everything below them.";
    };
  };

  compile = layer: {
    inherit (layer) settings settingsUnset;
    lock = {
      inherit (layer.lock) settings;
    };
  };

  violations =
    cfg:
    unique (
      concatMap (layer: filter helpers.isForbidden (helpers.dotPaths "" layer.settings)) (
        helpers.allLayers cfg
      )
    );
}
