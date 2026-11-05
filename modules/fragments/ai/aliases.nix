{
  optionPath ? [
    "ai"
    "aliases"
  ],
}:
{
  lib,
  ...
}:
let
  inherit (builtins) attrNames;
  inherit (lib)
    mapAttrs
    mkOption
    setAttrByPath
    types
    ;
  inherit (types)
    enum
    str
    submodule
    ;

  providers = import ./providers.nix;

  aliasType = submodule {
    options = {
      provider = mkOption {
        type = enum (attrNames providers);
        description = "The model provider.";
      };

      model = mkOption {
        type = str;
        description = "The model to use.";
      };
    };
  };

  defaults = {
    singleTurn = {
      provider = "openrouter";
      model = "~deepseek/deepseek-flash-latest";
    };
  };

  mkAliasOption =
    name:
    mkOption {
      type = aliasType;
      default = defaults.${name};
      description = "Single-turn workload alias for ${name} consumers.";
    };
in
{
  options = setAttrByPath optionPath (mapAttrs (name: _: mkAliasOption name) defaults);
}
