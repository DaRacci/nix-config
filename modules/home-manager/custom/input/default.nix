{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.input;
  keys = lib.mine.keys.alphanumericKeys;

  keyType =
    with lib.types;
    submodule {
      options = {
        name = lib.mkOption {
          readOnly = true;
          type = str;
          description = "The alphanumeric name of the key";
        };

        char = lib.mkOption {
          readOnly = true;
          type = str;
          description = "The character representation of the key";
        };
        vscode = lib.mkOption {
          readOnly = true;
          type = str;
          description = "How the key is labeled in VSCode";
        };
        zed-editor = lib.mkOption {
          readOnly = true;
          type = str;
          description = "How the key is labeled in Zed Editor";
        };
        micro = lib.mkOption {
          readOnly = true;
          type = str;
          description = "How the key is labeled in Micro";
        };
      };
    };

  keymap = lib.pipe keys [
    (map lib.toLower)
    lib.unique # Remove the duplicates because of upper and lower case
    (map (
      key:
      lib.nameValuePair (lib.toUpper key) {
        name = key;
        char = lib.mine.keys.getCharFromName key;
        vscode = key;
        zed-editor = key;
        # Micro is lowercase unless its a named key like "Enter" then its first letter capitalized
        micro =
          if builtins.stringLength key == 1 then
            key
          else
            let
              charList = lib.stringToCharacters key;
            in
            "${lib.toUpper (builtins.head charList)}${builtins.concatStringsSep "" (builtins.tail charList)}";
      }
    ))
    builtins.listToAttrs
  ];

  actions = lib.pipe (builtins.fromJSON (builtins.readFile ./bindings.json)).bindings [
    (builtins.map (action: lib.nameValuePair action.name action))
    builtins.listToAttrs
  ];

  keybindOption = lib.mkOption {
    type =
      with lib.types;
      nullOr (oneOf [
        str
        keyType
        (listOf keyType)
      ]);
    description = "The key(s) to use for this action";
    default = null;
    apply =
      key:
      if key == null then
        null
      else if lib.isString key then
        let
          keys = lib.splitString "+" key;
          keyAttrs = builtins.map (key: (builtins.getAttr (lib.toUpper key) keymap)) keys;
        in
        keyAttrs
      else
        key;
  };

  # Get the keybinds that have keys setup for the bind option.
  definedKeybinds = lib.pipe cfg.keybinds [
    (lib.filterAttrs (_: keybind: keybind != null))
    (lib.mapAttrs (
      name: keybind: {
        bind = keybind;
        action = builtins.getAttr name actions;
      }
    ))
  ];

  bindingsForEditor =
    editor:
    lib.pipe definedKeybinds [
      (lib.filterAttrs (_: keybind: (builtins.getAttr editor keybind.action) != null))
      (lib.mapAttrs (
        _: keybind: {
          inherit (builtins.getAttr editor keybind.action) action context;
          bind = builtins.map (key: builtins.getAttr editor key) keybind.bind;
        }
      ))
    ];
in
{
  options.custom.input = {
    enable = lib.mkEnableOption "Input configuration";

    # For user to use during configuration of keybinds
    keymap = lib.mkOption {
      description = "Keymap for various keys";
      type = lib.types.attrsOf keyType;
      readOnly = true;
      default = keymap;
    };

    keybinds = lib.mkOption {
      type = lib.types.submodule {
        options = builtins.mapAttrs (_name: _: keybindOption) actions;
      };
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor.userKeymaps =
      let
        bindingToAttrName = bind: if lib.isList bind then lib.concatStringsSep "-" bind else bind;

        bindings = builtins.fromJSON (builtins.readFile ./bindings.json);
        # get a list of the contexts by iterating each binding, getting the context and then removing duplicates
        editorContexts = builtins.listToAttrs (builtins.unique (builtins.map (binding: binding.context) bindings));
      in
      lib.pipe editorContexts [
        builtins.attrValues
        (builtins.map (context: {
          context = context.zed-editor;
          bindings = lib.pipe (bindingsForEditor "zed-editor") [
            builtins.attrValues
            (builtins.filter (keybind: keybind.editorContext == context.zed-editor))
            (builtins.map (keybind: lib.nameValuePair (bindingToAttrName keybind.bind) keybind.action))
            builtins.listToAttrs
          ];
        }))
        (lib.filter (value: value.bindings != { }))
      ];

    programs.vscode.keybindings = lib.pipe (bindingsForEditor "vscode") [
      builtins.attrValues
      (builtins.map (
        keybind:
        let
          bindingToAttrName = bind: if lib.isList bind then lib.concatStringsSep "+" bind else bind;
        in
        {
          key = bindingToAttrName keybind.bind;
          command = keybind.action;
          when = keybind.editorContext;
        }
      ))
    ];

    xdg.configFile."micro/bindings.json".text =
      let
        bindingToAttrName = bind: if lib.isList bind then lib.concatStringsSep "-" bind else bind;
      in
      lib.generators.toJSON { } (
        lib.pipe (bindingsForEditor "micro") [
          builtins.attrValues
          (builtins.map (keybind: lib.nameValuePair (bindingToAttrName keybind.bind) keybind.action))
          builtins.listToAttrs
        ]
      );
  };
}
