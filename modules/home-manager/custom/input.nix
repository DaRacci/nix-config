{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.custom.input;

  # Use the nix built-in ascii-table and then extend for special keys
  keys =
    (lib.attrNames (import "${inputs.nixpkgs}/lib/ascii-table.nix"))
    ++ [
      "SHIFT"
      "CTRL"
      "MOD"
      "ALT"
      "FN"
      "ENTER"
      "TAB"
      "ESC"
      "BACKSPACE"
      "DELETE"
      "INSERT"
      "HOME"
      "END"
      "PAGE_UP"
      "PAGE_DOWN"
      "PRINT"
      "PAUSE"
      "BREAK"
      "CAPS_LOCK"
      "NUM_LOCK"
      "SCROLL_LOCK"
      "UP"
      "DOWN"
      "LEFT"
      "RIGHT"
    ]
    ++ (map (i: "F${toString i}") (lib.range 1 24));

  getAlphanumericName =
    key:
    if (builtins.stringLength key > 1 || (lib.strings.match "([A-Za-z]+)" key) != null) then
      key
    else
      (builtins.replaceStrings
        [
          " "
          "_"
          "-"
          "+"
          "`"
          "="
          "["
          "]"
          "\\"
          ";"
          "'"
          ","
          "."
          "/"
          "{"
          "}"
          "|"
          ":"
          "\""
          "<"
          ">"
          "?"
          "!"
          "#"
          "$"
          "%"
          "("
          ")"
          "*"
          "^"
          "~"
          "@"
          "&"
        ]
        [
          "SPACE"
          "UNDERSCORE"
          "MINUS"
          "PLUS"
          "BACKTICK"
          "EQUALS"
          "LEFT_BRACKET"
          "RIGHT_BRACKET"
          "BACKSLASH"
          "SEMICOLON"
          "APOSTROPHE"
          "COMMA"
          "PERIOD"
          "SLASH"
          "LEFT_CURLY_BRACKET"
          "RIGHT_CURLY_BRACKET"
          "PIPE"
          "COLON"
          "DOUBLE_QUOTE"
          "LESS_THAN"
          "GREATER_THAN"
          "QUESTION_MARK"
          "EXCLAMATION_MARK"
          "HASH"
          "DOLLAR"
          "PERCENT"
          "LEFT_PARENTHESIS"
          "RIGHT_PARENTHESIS"
          "ASTERISK"
          "CARET"
          "TILDE"
          "AT"
          "AMPERSAND"
        ]
        key
      );

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
    (lib.drop 3)
    (map lib.toLower)
    lib.unique # Remove the duplicates because of upper and lower case
    (map (
      key:
      let
        alphaName = getAlphanumericName key;
        lowerAlphaName = lib.toLower alphaName;
      in
      lib.nameValuePair (lib.toUpper alphaName) {
        name = alphaName;
        char = key;
        vscode = lowerAlphaName;
        zed-editor = lowerAlphaName;
        # Micro is lowercase unless its a named key like "Enter" then its first letter capitalized
        micro =
          if builtins.stringLength key == 1 then
            lowerAlphaName
          else
            let
              charList = lib.stringToCharacters lowerAlphaName;
            in
            "${lib.toUpper (builtins.head charList)}${builtins.concatStringsSep "" (builtins.tail charList)}";
      }
    ))
    builtins.listToAttrs
  ];

  editorContexts = {
    editor = {
      vscode = "editorTextFocus";
      zed-editor = "Editor";
      micro = "buffer";
    };
    editorFull = {
      vscode = "editorTextFocus && !editorReadOnly";
      zed-editor = "Editor && mode == full";
      micro = "buffer";
    };
  };

  # If an editors value is set to null, then it is not supported.
  actions = {
    NewLine = {
      editorContext = editorContexts.editorFull;
      zed-editor = "editor::NewLine";
      vscode = null;
      micro = "InsertNewLine";
    };
    NewLineAbove = {
      editorContext = editorContexts.editorFull;
      zed-editor = "editor::NewLineAbove";
      vscode = "editor.action.insertLineBefore";
      micro = null;
    };
    NewLineBelow = {
      editorContext = editorContexts.editorFull;
      zed-editor = "editor::NewLineBelow";
      vscode = "editor.action.insertLineAfter";
      micro = null;
    };
    SelectLine = {
      editorContext = editorContexts.editor;
      zed-editor = "editor::SelectLine";
      vscode = "editor.action.selectLines";
      micro = "SelectLine";
    };
  };

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
          bind = builtins.map (key: builtins.getAttr editor key) keybind.bind;
          editorContext = builtins.getAttr editor keybind.action.editorContext;
          action = builtins.getAttr editor keybind.action;
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
      in
      lib.pipe editorContexts [
        builtins.attrValues
        (builtins.map (context: {
          inherit (context) zed-editor;
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
