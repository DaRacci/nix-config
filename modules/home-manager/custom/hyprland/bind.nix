{ config, lib, ... }:
with lib.types;
let
  inherit (lib) mkOption;
  cfg = config.wayland.windowManager.hyprland.custom-settings.bind;

  keybindOption = lib.mkOption {
    type = lib.mine.keys.keyType;

    description = "The key(s) to use for this action";
    default = null;
  };

  bindModifiersOption = mkOption {
    type =
      let
        mods = enum [
          "l" # locked, will also work when an input inhibitor (e.g. a lockscreen) is active.
          "r" # release, will trigger on release of a key.
          "o" # longPress, will trigger on long press of a key.
          "e" # repeat, will repeat when held.
          "n" # non-consuming, key/mouse events will be passed to the active window in addition to triggering the dispatcher.
          "m" # mouse, see below.
          "t" # transparent, cannot be shadowed by other binds.
          "i" # ignore mods, will ignore modifiers.
          "s" # separate, will arbitrarily combine keys between each mod/key, see [Keysym combos](#keysym-combos) above.
          "d" # has description, will allow you to write a description for your bind.
          "p" # bypasses the app's requests to inhibit keybinds.
        ];
      in
      nullOr (either mods (listOf mods));
    default = null;
    description = "The modifier keys to use for this action";
    apply =
      mods:
      if mods == null then
        null
      else if lib.isList mods then
        mods
      else
        [ mods ];
  };

  actionOption = mkOption {
    type = either str (listOf str);
    description = "The action to perform when the keybind is triggered.";
    apply = action: if lib.isList action then action else [ action ];
  };
in
{
  options.wayland.windowManager.hyprland.custom-settings = {
    bind = mkOption {
      type =
        with types;
        (listOf (submodule {
          options = {
            keybind = keybindOption;
            modifiers = bindModifiersOption;
            action = actionOption;
          };
        }));
      default = [ ];
      description = "Binding rules.";
    };
  };

  config = {
    wayland.windowManager.hyprland.settings = lib.pipe cfg [
      (builtins.groupBy (
        attr: "bind${lib.concatStrings (if attr.modifiers != null then attr.modifiers else [ ])}"
      ))
      (builtins.mapAttrs (
        _: list:
        builtins.map (
          bind:
          let
            modifierKeys = lib.mine.keys.getModifiersFromList bind.keybind;
            modifiers = builtins.concatStringsSep "+" modifierKeys;
            keybind = builtins.concatStringsSep "," (
              builtins.filter (k: !builtins.elem k modifierKeys) bind.keybind
            );
            action = builtins.concatStringsSep "," bind.action;
          in
          "${modifiers}, ${keybind}, ${action}"
        ) list
      ))
    ];
  };
}
