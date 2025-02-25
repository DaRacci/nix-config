{ inputs, lib, ... }:
rec {
  asciiKeys = import "${inputs.nixpkgs}/lib/ascii-table.nix";

  numberKeys = lib.map toString (lib.range 0 9);

  modifierKeys = [
    "SHIFT"
    "CTRL"
    "MOD"
    "SUPER"
    "META"
    "ALT"
    "FN"
  ];

  specialKeys = [
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
  ];

  functionKeys = map (i: "F${toString i}") (lib.range 1 48);

  directionalKeys = [
    "LEFT"
    "RIGHT"
    "UP"
    "DOWN"
  ];

  symbols = {
    "SPACE" = " ";
    "EXCLAMATION" = "!";
    "AT" = "@";
    "HASH" = "#";
    "DOLLAR" = "$";
    "PERCENT" = "%";
    "CARET" = "^";
    "AMPERSAND" = "&";
    "ASTERISK" = "*";
    "LEFT_PAREN" = "(";
    "RIGHT_PAREN" = ")";
    "MINUS" = "-";
    "UNDERSCORE" = "_";
    "EQUALS" = "=";
    "PLUS" = "+";
    "LEFT_BRACKET" = "[";
    "RIGHT_BRACKET" = "]";
    "LEFT_BRACE" = "{";
    "RIGHT_BRACE" = "}";
    "SEMICOLON" = ";";
    "COLON" = ":";
    "QUOTE" = "'";
    "DOUBLE_QUOTE" = "\"";
    "BACKTICK" = "`";
    "TILDE" = "~";
    "COMMA" = ",";
    "LESS_THAN" = "<";
    "PERIOD" = ".";
    "GREATER_THAN" = ">";
    "SLASH" = "/";
    "QUESTION" = "?";
    "BACKSLASH" = "\\";
    "PIPE" = "|";
  };

  alphanumericKeys = lib.concatLists [
    (lib.mine.attrsets.getAttrsByValue (lib.range 65 90) asciiKeys) # A-Z
    (lib.mine.attrsets.getAttrsByValue (lib.range 97 122) asciiKeys) # a-z
    numberKeys
    modifierKeys
    specialKeys
    directionalKeys
    (builtins.attrNames symbols)
    functionKeys
  ];

  getAlphanumericName =
    char:
    if (builtins.stringLength char > 1) then
      throw "Invalid key provided, expected a single character"
    else if (lib.strings.match "([A-Za-z0-9]+)" char) != null then
      char
    else
      lib.getAttr symbols char;

  getCharFromName = name: if (builtins.hasAttr name symbols) then name else name;

  getModifiersFromList = list: builtins.filter (k: builtins.elem k modifierKeys) list;

  alphanumericKeysEnum = lib.types.enum alphanumericKeys;

  keyType =
    with lib.types;
    (oneOf [
      (either str alphanumericKeysEnum)
      (listOf (either str alphanumericKeysEnum))
    ])
    // {
      check =
        key:
        if key == null then
          false
        else if lib.isString key then
          builtins.elem (lib.toUpper key) alphanumericKeys
        else if lib.isList key then
          let
            invalidKeys = builtins.filter (k: !builtins.elem (lib.toUpper k) alphanumericKeys) key;
          in
          if builtins.length invalidKeys == 0 then
            true
          else
            throw "Invalid key provided, the following are not valid alphanumeric keys: ${lib.concatStringsSep ", " invalidKeys}"
        else
          false;
    };
}
