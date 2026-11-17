{ lib }:
let
  inherit (lib)
    concatMap
    hasPrefix
    mkOption
    optional
    ;
  inherit (lib.types)
    attrsOf
    listOf
    str
    submodule
    ;

  linkType = submodule {
    options = {
      target = mkOption {
        type = str;
        description = "Path inside the profile home, relative.";
      };
      source = mkOption {
        type = str;
        description = "Absolute path inside the container to link to.";
      };
    };
  };

  deltaType = submodule {
    options = {
      include = mkOption {
        type = listOf str;
        default = [ ];
        description = "Targets or globs to put back after an `exclude`.";
      };
      exclude = mkOption {
        type = listOf str;
        default = [ ];
        description = "Targets or globs removed for this scope.";
      };
    };
  };
in
{
  options.links = {
    default = mkOption {
      type = listOf linkType;
      default = [ ];
      description = "The fleet-wide link list.";
    };

    classes = mkOption {
      type = attrsOf deltaType;
      default = { };
      description = "Per-class `include`/`exclude` deltas against `default`.";
    };

    profiles = mkOption {
      type = attrsOf deltaType;
      default = { };
      description = "Per-profile deltas, applied after the class deltas.";
    };
  };

  compile = cfg: {
    inherit (cfg.links) default classes profiles;
  };

  problems =
    cfg:
    concatMap (
      link:
      optional (hasPrefix "/" link.target) "links: target ${link.target} must be relative"
      ++ optional (!hasPrefix "/" link.source) "links: source ${link.source} must be absolute"
    ) cfg.links.default;
}
