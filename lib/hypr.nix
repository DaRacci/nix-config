{ lib, ... }:
rec {
  types = {
    # https://wiki.hyprland.org/Configuring/Binds/#bind-flags
    # Value is the short name representation of the bind modifier
    bindModifier = {
      locked = "l";
      release = "r";
      longPress = "o";
      repeat = "e";
      nonConsuming = "n";
      mouse = "m";
      transparent = "t";
      ignoreMods = "i";
      separate = "s";
      bypass = "p";
    };
  };

  enums = {
    bindModifier = lib.types.enum (builtins.attrNames types.bindModifier);
  };

  optionTypes = with lib.types; {
    bindModifier = lib.mkOption {
      type = oneOf [
        enums.bindModifier
        (listOf enums.bindModifier)
        nonEmptyStr
        (listOf nonEmptyStr)
      ];
      description = "The modifiers for this bind";
      apply =
        mods:
        let
          toEnum =
            m:
            let
              value = lib.mine.attrsets.getAttrNameByValue m types.bindModifier;
            in
            if value != null then m else throw "Invalid bind modifier: ${m}";
        in
        if lib.isList mods && builtins.all lib.isString mods then
          builtins.map toEnum mods
        else if lib.isString mods then
          [ (toEnum mods) ]
        else if !lib.isList mods then
          [ mods ]
        else
          mods;
    };
  };
}
