{
  optionPath ? [
    "ai"
    "models"
  ],
}:
{
  config,
  lib,
  ...
}:
let
  inherit (builtins)
    attrNames
    length
    ;
  inherit (lib)
    concatLists
    concatStringsSep
    getAttrFromPath
    mapAttrs
    mkOption
    setAttrByPath
    types
    unique
    ;
  inherit (types)
    enum
    int
    listOf
    str
    submodule
    ;

  providers = [
    "openrouter"
    "opencode-go"
  ];

  chainType = listOf (submodule {
    options = {
      provider = mkOption {
        type = enum providers;
        description = "The model provider.";
      };

      model = mkOption {
        type = str;
        description = "The model to use on the provider.";
      };

      priority = mkOption {
        type = int;
        description = "The priority for this entry. Lower values are tried first.";
      };
    };
  });

  defaults = {
    primary = {
      provider = "openrouter";
      model = "~deepseek/deepseek-flash-latest";
    };
    vision = {
      provider = "openrouter";
      model = "xiaomi/mimo-v2.5";
    };
    compression = {
      provider = "opencode-go";
      model = "deepseek-v4.1-flash";
    };
    simpleton = {
      provider = "openrouter";
      model = "inclusionai/ling-3.0-flash";
    };
    brains = {
      provider = "openrouter";
      model = "~deepseek/deepseek-pro-latest";
    };
  };

  descriptions = {
    primary = "The primary agent model.";
    vision = "The model used for image understanding.";
    compression = "The model used for context compression and summarisation.";
    simpleton = "The model used for low-reasoning, small-context tasks.";
    brains = "The model used for complex reasoning and decision-making.";
  };

  chains = attrNames defaults;
  cfg = getAttrFromPath optionPath config;

  optionName = name: concatStringsSep "." (optionPath ++ [ name ]);

  mkChainOption =
    name:
    mkOption {
      type = chainType;
      default = [ (defaults.${name} // { priority = 0; }) ];
      description = ''
        ${descriptions.${name}}

        The lowest priority value becomes the primary model, and the remaining
        entries become the ordered fallback chain. Priorities must be unique.
      '';
    };

  mkAssertions =
    name:
    let
      entries = cfg.${name};
      priorities = map (entry: entry.priority) entries;
      name' = optionName name;
    in
    [
      {
        assertion = entries != [ ];
        message = "${name'} must contain at least one model.";
      }
      {
        assertion = length priorities == length (unique priorities);
        message = "${name'} priorities must be unique.";
      }
    ];
in
{
  options = setAttrByPath optionPath (mapAttrs (name: _: mkChainOption name) defaults);

  config = {
    assertions = concatLists (map mkAssertions chains);
  };
}
