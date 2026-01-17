{ config, lib, ... }:
let
  inherit (lib) types mkOption listToAttrs nameValuePair concatStringsSep mapAttrsToList;
  inherit (types) attrsOf submodule str either nullOr int listOf;
  inherit (import ./types.nix { inherit lib; }) monitorSelector workspaceSelector percentString rule windowMatch;

  cfg = config.wayland.windowManager.hyprland.custom-settings;

  mkMatchersToUniqueName = baseName: matchers: lib.imap0 (i: v: nameValuePair "${baseName}-${i}" v)
    |> listToAttrs;

  mkRuleString =
    name: value: "${name} = ${toHyprValue value}";

  mkMatcherString =
    matcher:
    let
      nonNullMatchers = lib.filterAttrs (_: v: v != null) matcher;
    in
    if builtins.length (builtins.attrValues nonNullMatchers) == 0 then
      throw "At least one matcher must be set."
    else lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "match:${lib.mine.strings.toSnakeCase name} = ${toHyprValue value}") nonNullMatchers);

  getRuleName = attr: attr.internalName or (lib.mine.strings.toSnakeCase attr);

  toHyprValue = value: if (builtins.typeOf value == "bool")
    then
      if value
      then "1"
      else "0"
    else if builtins.typeOf value == "set"
    then "${lib.concatStringsSep " " (lib.mapAttrsToList (_name: toString) value)}"
    else toString value;

  mkWindowRuleString =
  windowRule:
    let
      inherit (windowRule) name rule matcher;
      matcherStrings = builtins.map mkMatcherString matcher;

      propStrings =
        rule
        |> lib.filterAttrs (_: v: v != null)
        |> lib.mapAttrsToList (name: value: mkRuleString (getRuleName name) value)
        |> concatStringsSep "\n";
    in lib.imap0 (i: matcher: ''
        windowrule {
          name = "${name}-${toString i}"
          ${matcher}

          ${propStrings}
        }
      '') matcherStrings;
in
{
  options.wayland.windowManager.hyprland.custom-settings = {
    windowrule = mkOption {
      type = attrsOf (submodule ({ name, ... }: {
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
        }));
      default = { };
      description = "Match rules for windows, these will always use the windowmanagerv2 keyword.";
    };
  };

  config = {
    wayland.windowManager.hyprland.extraConfig = cfg.windowrule
      |> lib.mapAttrsToList (windowRuleName: attrs: mkWindowRuleString attrs)
      |> lib.flatten
      |> concatStringsSep "\n";
  };
}
