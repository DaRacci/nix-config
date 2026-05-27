{ config, lib, ... }:
let
  inherit (lib)
    types
    toCamelCase
    mkOption
    isString
    splitString
    isList
    ;
  inherit (types)
    nonEmptyStr
    listOf
    either
    str
    attrsOf
    submodule
    oneOf
    ;
  inherit (builtins)
    head
    tail
    match
    listToAttrs
    filter
    elem
    elemAt
    concatStringsSep
    hasAttr
    mapAttrs
    ;

  cfg = config.wayland.windowManager.hyprland.custom-settings;

  mkSubmapKeybindOption =
    descMod:
    mkOption {
      type = oneOf [
        nonEmptyStr
        (listOf nonEmptyStr)
      ];
      description = "The keybind to ${descMod} the submap.";
      default = null;
      apply = keybind: if isString keybind then splitString "+" keybind else keybind;
    };

  keybindOption =
    name:
    mkOption {
      type = listOf nonEmptyStr;
      description = "The key(s) to use for this action";
      default = splitString "+" name;
      readOnly = true;
    };

  actionOption = mkOption {
    type = either str (listOf str);
    description = "The action to perform when the keybind is triggered.";
    apply = action: if isList action then action else [ action ];
  };

  # Convert modifier name list (e.g. ["locked" "repeat"]) to Lua flags attrset
  mkLuaFlags =
    modifiers:
    listToAttrs (
      map (m: {
        name = toCamelCase m;
        value = true;
      }) modifiers
    );

  mkLuaKeyCombo =
    keybindList:
    let
      # Normalize case: if uppercased key is a known modifier, use uppercase form
      # e.g. "Ctrl" -> "CTRL", "Shift" -> "SHIFT" (already uppercase)
      normalizeKey =
        k: if elem (lib.strings.toUpper k) lib.mine.keys.modifierKeys then lib.strings.toUpper k else k;
      normalizedList = map normalizeKey keybindList;
      modKeys = lib.mine.keys.getModifiersFromList normalizedList;
      otherKeys = filter (k: !elem k modKeys) normalizedList;
    in
    concatStringsSep " + " (modKeys ++ otherKeys);

  # Convert single-char direction (l/r/u/d) to full word (left/right/up/down).
  dirWord = {
    l = "left";
    r = "right";
    u = "up";
    d = "down";
  };

  toLua = lib.generators.toLua { };

  # Build a Lua hl.dsp.* expression for a dispatcher call.
  # action is a list like ["exec", "kitty"] or ["resizeactive", "0 50"].
  # Known dispatchers map to hl.dsp.* API; unknown/custom fallback to
  # hl.dsp.exec_cmd("hyprctl dispatch ...").
  mkLuaAction =
    action:
    let
      dispatcher = head action;
      args = tail action;
      q = toLua;

      known = {
        exec = a: "hl.dsp.exec_cmd(${q (concatStringsSep " " a)})";
        submap = a: "hl.dsp.submap(${q (head a)})";
        workspace = a: "hl.dsp.focus({ workspace = ${q (head a)} })";
        movetoworkspace = a: "hl.dsp.window.move({ workspace = ${q (head a)} })";
        togglespecialworkspace = a: "hl.dsp.workspace.toggle_special(${q (head (a ++ [ "" ]))})";
        resizeactive =
          a:
          let
            raw = head a;
            # Repo passes single int (direction * magnitude) or string "x y".
            parts = match "(-?[0-9]+)[[:space:]]+(-?[0-9]+)" (toString raw);
            x = if parts != null then elemAt parts 0 else toString raw;
            y = if parts != null then elemAt parts 1 else "0";
          in
          "hl.dsp.window.resize({ x = ${x}, y = ${y}, relative = true })";
        movefocus =
          a:
          let
            raw = head a;
            dir = dirWord.${raw} or raw;
          in
          "hl.dsp.focus({ direction = ${q dir} })";
        movewindow =
          a:
          let
            raw = head a;
            dir = dirWord.${raw} or raw;
          in
          "hl.dsp.window.move({ direction = ${q dir} })";
        killactive = _: "hl.dsp.window.kill()";
        fullscreen = _: "hl.dsp.window.fullscreen()";
        togglefloating = _: "hl.dsp.window.float({ action = \"toggle\" })";
      };
    in
    lib.generators.mkLuaInline (
      if hasAttr dispatcher known then
        known.${dispatcher} args
      else
        # space-separated dispatcher args: hyprctl dispatch <name> <arg1> <arg2> ...
        let
          spaceArgs = concatStringsSep " " (map toString args);
        in
        "hl.dsp.exec_cmd(${q "hyprctl dispatch ${dispatcher}${lib.optionalString (spaceArgs != "") " ${spaceArgs}"}"})"
    );

  mkLuaBindArgs =
    keybind: action: modifiers:
    let
      keyStr = mkLuaKeyCombo keybind;
      actionLua = mkLuaAction action;
      flags = mkLuaFlags modifiers;
    in
    if flags != null then
      [
        keyStr
        actionLua
        flags
      ]
    else
      [
        keyStr
        actionLua
      ];

  # Build Lua bind entries from our bind attrset
  mkLuaBinds =
    binds:
    lib.pipe binds [
      lib.attrsToList
      (map (v: {
        _args = mkLuaBindArgs v.value.keybind v.value.action v.value.modifiers;
      }))
    ];

  # Build Lua submap entries from our submaps attrset
  mkLuaSubmaps =
    submaps:
    lib.pipe submaps [
      (lib.mapAttrsToList (
        name: submap:
        lib.nameValuePair name {
          settings.bind =
            mkLuaBinds submap.binds
            ++ lib.optional (submap.reset != null) {
              _args = [
                (mkLuaKeyCombo submap.reset)
                (mkLuaAction [
                  "submap"
                  "reset"
                ])
              ];
            };
        }
      ))
      lib.listToAttrs
    ];

  # Build Lua enter-bind entries for each submap (emitted at top level)
  mkLuaEnterBinds =
    submaps:
    lib.pipe submaps [
      (lib.mapAttrsToList (
        name: submap:
        lib.optional (submap.enter != null) {
          _args = [
            (mkLuaKeyCombo submap.enter)
            (mkLuaAction [
              "submap"
              name
            ])
          ];
        }
      ))
      lib.concatLists
    ];
in
{
  options.wayland.windowManager.hyprland.custom-settings = rec {
    bind = mkOption {
      type = attrsOf (
        either (listOf nonEmptyStr) (
          submodule (
            { name, ... }:
            {
              options = {
                keybind = keybindOption name;
                modifiers = lib.mine.hypr.optionTypes.bindModifier // {
                  default = [ ];
                };
                action = actionOption;
              };
            }
          )
        )
      );
      apply =
        attrs:
        mapAttrs (
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
      settings.bind = mkLuaBinds cfg.bind ++ mkLuaEnterBinds cfg.submaps;
      submaps = mkLuaSubmaps cfg.submaps;
    };
  };
}
