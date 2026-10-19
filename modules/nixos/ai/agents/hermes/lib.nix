{ lib }:
let
  inherit (lib) mkIf mkEnableOption optional;
  inherit (builtins)
    filter
    isAttrs
    listToAttrs
    hasAttr
    isList
    foldl'
    ;

  # Takes a list of packages, returning a list of the same packages with any packages matching depNames removed.
  depsMinusNamed =
    depNames: pkgs:
    let
      depNamesSet = listToAttrs (
        map (name: {
          inherit name;
          value = true;
        }) depNames
      );
      isNotNamedDep = pkg: !(hasAttr (lib.getName pkg) depNamesSet);
    in
    filter isNotNamedDep pkgs;

  # Deep merge with list concatenation, so feature toggles can append instead of clobbering.
  mergeDeep =
    lhs: rhs:
    if isAttrs lhs && isAttrs rhs then
      lhs // lib.mapAttrs (name: value: if lhs ? ${name} then mergeDeep lhs.${name} value else value) rhs
    else if isList lhs && isList rhs then
      lhs ++ rhs
    else
      rhs;

  # Create a simple option and config module for plugins.
  mkPluginModule =
    config:
    {
      name,
      extraPackages ? [ ],
      extraPythonPackages ? [ ],
      extraPluginSrc ? null,

      # Override the plugin name that is used to load the plugin.
      pluginName ? name,

      settings ? { },
    }:
    {
      options.services.ai-agent.plugins.${pluginName} = {
        enable = mkEnableOption "${pluginName} plugin";
      };

      config = mkIf (config.services.ai-agent.plugins.${pluginName}.enable) {
        services = {
          ai-agent.settings = settings // {
            plugins.enabled = [ pluginName ];
          };
          hermes-agent = {
            inherit extraPackages extraPythonPackages;
            extraPlugins = optional (extraPluginSrc != null) extraPluginSrc;
          };
        };
      };
    };

  hermesConfigType = lib.types.mkOptionType {
    name = "ai-agent-hermes-settings";
    description = "Hermes config attrs, deep-merged with list concatenation.";
    check = isAttrs;
    merge = _loc: defs: foldl' mergeDeep { } (map (d: d.value) defs);
  };
in
{
  inherit
    depsMinusNamed
    mergeDeep
    mkPluginModule
    hermesConfigType
    ;
}
