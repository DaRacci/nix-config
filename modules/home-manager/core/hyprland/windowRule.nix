{ config, lib, ... }:
let
  inherit (lib)
    types
    mkOption
    ;
  inherit (types)
    attrsOf
    submodule
    str
    listOf
    ;
  inherit (import ./types.nix { inherit lib; }) rule windowMatch;

  cfg = config.wayland.windowManager.hyprland.custom-settings;

  # Ordered string from known keys, filtering null fields so partial structs don't emit junk
  compoundStr =
    keys: v:
    let
      vals = builtins.filter (x: x != null) (map (k: v.${k}) keys);
    in
    lib.concatStringsSep " " (map toString vals);

  luaWorkspaceStr =
    v:
    if v.special != null then
      let
        s = if builtins.isString v.special then v.special else toString v.special;
      in
      if s == "" || s == "special" then "special" else "special:${s}"
    else if v.name != null then
      v.name
    else if v.id != null then
      toString v.id
    else if v.relativeId != null then
      toString v.relativeId
    else
      "";

  luaMonitorStr =
    v:
    if v.name != null then
      v.name
    else if v.index != null then
      toString v.index
    else
      "";

  luaOpacityStr =
    v:
    if builtins.typeOf v == "float" || builtins.typeOf v == "int" then
      toString v
    else
      lib.concatStringsSep " " (
        builtins.filter (x: x != null) [
          (lib.optionalString (v.activeopacity != null) (toString v.activeopacity))
          (lib.optionalString (v.inactiveopacity != null) (toString v.inactiveopacity))
          (lib.optionalString (v.additionalopacity != null) (toString v.additionalopacity))
        ]
      );

  # Convert a rule value to Lua-appropriate form
  # Several compound types (workspace, monitor, move, size, etc.) are string-valued in Lua API
  toLuaRuleValue =
    ruleName: value:
    let
      sn = lib.mine.strings.toSnakeCase ruleName;
      tn = builtins.typeOf value;
    in
    if sn == "workspace" then
      luaWorkspaceStr value
    else if sn == "monitor" then
      luaMonitorStr value
    else if sn == "fullscreen_state" then
      compoundStr [ "internal" "client" ] value
    else if sn == "max_size" || sn == "min_size" then
      compoundStr [ "width" "height" ] value
    else if sn == "opacity" then
      luaOpacityStr value
    else if sn == "move" then
      "${toString value.x or ""} ${toString value.y or ""}"
    else if sn == "center" then
      if tn == "bool" then
        value
      else if value.center != null then
        value.center
      else
        true
    else
      value;

  # Build match attrs: flatten fullscreenstate into fullscreen_state_internal/client keys
  # workspace selectors stringified via luaWorkspaceStr; content int-values stringified
  mkLuaMatcherAttrs =
    matcher:
    let
      nonNullMatchers = lib.filterAttrs (_: v: v != null) matcher;
    in
    if builtins.length (builtins.attrValues nonNullMatchers) == 0 then
      throw "At least one matcher must be set."
    else
      lib.foldl' (
        acc: name:
        let
          v = nonNullMatchers.${name};
        in
        if name == "fullscreenstate" then
          acc
          // (lib.optionalAttrs (v.internal != null) {
            fullscreen_state_internal = v.internal;
          })
          // (lib.optionalAttrs (v.client != null) {
            fullscreen_state_client = v.client;
          })
        else if name == "workspace" then
          acc // { workspace = luaWorkspaceStr v; }
        else if name == "content" then
          acc // { content = toString v; }
        else
          acc // { "${lib.mine.strings.toSnakeCase name}" = v; }
      ) { } (builtins.attrNames nonNullMatchers);

  mkLuaWindowRuleEntries =
    windowRule:
    let
      inherit (windowRule) name rule matcher;
      nonNullRules = lib.filterAttrs (_: v: v != null) rule;
      # Preserve all values (including false bools), convert compound types to string
      luaRuleAttrs = lib.mapAttrs' (
        n: v: lib.nameValuePair (lib.mine.strings.toSnakeCase n) (toLuaRuleValue n v)
      ) nonNullRules;
    in
    lib.imap0 (
      i: m:
      luaRuleAttrs
      // {
        name = "${name}-${toString i}";
        match = mkLuaMatcherAttrs m;
      }
    ) matcher;

  windowruleEntries =
    cfg.windowrule |> lib.mapAttrsToList (_windowRuleName: mkLuaWindowRuleEntries) |> lib.flatten;
in
{
  options.wayland.windowManager.hyprland.custom-settings = {
    windowrule = mkOption {
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              name = mkOption {
                type = str;
                default = name;
                description = "The name of the window rule.";
              };
              matcher = mkOption {
                type = listOf (submodule windowMatch);
                default = [ ];
              };
              rule = mkOption { type = submodule rule; };
            };
          }
        )
      );
      default = { };
      description = "Match rules for windows, these will always use the windowmanagerv2 keyword.";
    };
  };

  config = {
    wayland.windowManager.hyprland.settings.window_rule = windowruleEntries;
  };
}
