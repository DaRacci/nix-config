{ config, lib, ... }:
with lib.types;
let
  inherit (lib) mkOption;
  cfg = config.wayland.windowManager.hyprland.custom-settings;

  mkBindKeyword = modifiers: "bind${lib.concatStrings modifiers}";

  mkSubmapKeybindOption =
    descMod:
    lib.mkOption {
      type = oneOf [
        nonEmptyStr
        lib.mine.keys.keyType
        (listOf lib.mine.keys.keyType)
      ];
      description = "The keybind to ${descMod} the submap.";
      default = null;
      apply = keybind: if lib.isString keybind then lib.splitString "+" keybind else keybind;
    };

  keybindOption =
    name:
    lib.mkOption {
      type = lib.mine.keys.keyType;
      description = "The key(s) to use for this action";
      default = lib.splitString "+" name;
      readOnly = true;
    };

  actionOption = mkOption {
    type = either str (listOf str);
    description = "The action to perform when the keybind is triggered.";
    apply = action: if lib.isList action then action else [ action ];
  };

  mkBind =
    keybind: action:
    let
      keybindList = if builtins.isString keybind then [ keybind ] else keybind;
      modifierKeys = lib.mine.keys.getModifiersFromList keybindList;
      modifiers = builtins.concatStringsSep "+" modifierKeys;
      joinedKeybind = builtins.concatStringsSep "," (
        builtins.filter (k: !builtins.elem k modifierKeys) keybindList
      );
      joinedAction = builtins.concatStringsSep "," action;
    in
    "${modifiers}, ${joinedKeybind}, ${joinedAction}";
in
{
  options.wayland.windowManager.hyprland.custom-settings = with types; rec {
    bind = mkOption {
      type = attrsOf (
        either (listOf nonEmptyStr) (
          submodule (
            { name, ... }:
            {
              options = {
                keybind = keybindOption name;
                modifiers = lib.mine.hypr.optionTypes.bindModifier;
                action = actionOption;
              };
            }
          )
        )
      );
      apply =
        attrs:
        builtins.mapAttrs (
          name: obj:
          {
            keybind = lib.splitString "+" name;
            modifiers = [ ];
          }
          // (
            if lib.isList obj then
              {
                action = obj;
              }
            else
              obj
          )
        ) attrs;
      default = { };
      description = "Binding rules";
    };

    submaps = mkOption {
      type = attrsOf (submodule {
        options = {
          enter = mkSubmapKeybindOption "activate";
          reset = mkSubmapKeybindOption "reset";
          binds = bind;
        };
      });
    };
  };

  config = {
    wayland.windowManager.hyprland = {
      settings = lib.mine.attrsets.recursiveMergeAttrs [
        (lib.pipe cfg.bind [
          lib.attrsToList
          (builtins.groupBy (v: mkBindKeyword v.value.modifiers))
          (builtins.mapAttrs (_: list: builtins.map (v: mkBind v.value.keybind v.value.action) list))
        ])
      ];

      extraConfig = lib.pipe cfg.submaps [
        (lib.mapAttrsToList (
          name: submap:
          ''
            bind=${
              mkBind submap.enter [
                "submap"
                name
              ]
            }
            submap=${name}
          ''
          + (lib.pipe submap.binds [
            (lib.mapAttrsToList (name: bind: "${mkBindKeyword bind.modifiers}=${mkBind name bind.action}"))
            (builtins.concatStringsSep "\n")
          ])
          + ''

            bind=${
              mkBind submap.reset [
                "submap"
                "reset"
              ]
            }
            submap=reset
          ''
        ))
        # builtins.concatLists
        (builtins.concatStringsSep "\n")
      ];
    };
  };
}
