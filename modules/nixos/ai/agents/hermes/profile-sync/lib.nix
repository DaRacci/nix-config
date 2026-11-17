{ lib }:
let
  inherit (lib)
    any
    attrByPath
    concatLists
    elem
    filter
    hasAttr
    hasPrefix
    mapAttrsToList
    reverseList
    splitString
    ;
  inherit (builtins)
    attrValues
    isAttrs
    ;
in
rec {
  allLayers = cfg: [ cfg.defaults ] ++ attrValues cfg.classes ++ attrValues cfg.profiles;

  dotPaths =
    prefix: value:
    if isAttrs value then
      concatLists (
        mapAttrsToList (key: child: dotPaths (if prefix == "" then key else "${prefix}.${key}") child) value
      )
    else
      [ prefix ];

  forbiddenRoots = [
    "_config_version"
    "command_allowlist"
    "context"
    "dashboard"
    "delegation.model"
    "delegation.provider"
    "display.pet"
    "display.skin"
    "gateway.profile_routes"
    "kanban.dispatch_profiles"
    "mcp_servers"
    "memory.mnemosyne.ignore_patterns"
    "memory.mnemosyne.reflect"
    "memory.mnemosyne.sync_roles"
    "moa"
    "platform_toolsets"
    "platforms.webhook"
    "skills.disabled"
    "telemetry.shared_metrics"
    "tts"
  ];

  isForbidden = path: any (root: path == root || hasPrefix "${root}." path) forbiddenRoots;

  classChain =
    classes: name:
    let
      go =
        seen: current:
        if current == null || !(hasAttr current classes) then
          seen
        else if elem current seen then
          seen ++ [ current ]
        else
          go (seen ++ [ current ]) classes.${current}.inherits;
    in
    go [ ] name;

  # defaults -> outer class -> ... -> the profile itself.
  layerChain =
    defaults: classes: entry:
    let
      chain = if entry.class == null then [ ] else classChain classes entry.class;
    in
    [ defaults ] ++ map (name: classes.${name}) (reverseList chain) ++ [ entry ];

  # The values a set of layers assigns to one key, nulls dropped.
  assignments =
    layers: get: key:
    filter (value: value != null) (
      map (layer: attrByPath (splitString "." key) null (get layer)) layers
    );
}
