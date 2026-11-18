{ lib }:
let
  inherit (lib)
    foldl'
    mkOption
    recursiveUpdate
    ;
  inherit (lib.types)
    attrsOf
    nullOr
    str
    submodule
    ;

  settingsArea = import ./settings.nix { inherit lib; };
  envArea = import ./env.nix { inherit lib; };
  identityArea = import ./identity.nix { inherit lib; };
  linksArea = import ./links.nix { inherit lib; };

  vocabulary.options =
    settingsArea.options
    // envArea.options
    // {
      lock = settingsArea.lockOptions // envArea.lockOptions;
    };

  classType = submodule (
    { ... }:
    {
      imports = [ vocabulary ];
      options.inherits = mkOption {
        type = nullOr str;
        default = null;
        description = "Another class whose vocabulary this one starts from.";
      };
    }
  );

  profileType = submodule (
    { ... }:
    {
      imports = [ vocabulary ];
      options.class = mkOption {
        type = nullOr str;
        default = null;
        description = "The class this profile belongs to.";
      };
    }
  );

  # Every area contributes its own slice of one layer's compiled form.
  areas = [
    settingsArea
    envArea
    identityArea
  ];

  compileLayer = layer: foldl' recursiveUpdate { } (map (area: area.compile layer) areas);
in
{
  options = {
    defaults = mkOption {
      type = submodule vocabulary;
      default = { };
      description = "The baseline every profile gets.";
    };

    classes = mkOption {
      type = attrsOf classType;
      default = { };
      description = "Reusable bundles of the same vocabulary.";
    };

    profiles = mkOption {
      type = attrsOf profileType;
      default = { };
      description = "Per-profile deltas. A profile with no entry here gets `defaults` only, and the run report lists it as undeclared.";
    };

    links = linksArea.options.links;
  };

  compile = cfg: {
    version = 1;
    defaults = compileLayer cfg.defaults;
    classes = builtins.mapAttrs (_: compileLayer) cfg.classes;
    profiles = builtins.mapAttrs (_: compileLayer) cfg.profiles;
    links = linksArea.compile cfg;
  };
}
