{
  lib,
  ...
}:
let
  inherit (builtins) elem concatStringsSep;
  inherit (lib)
    head
    tail
    match
    length
    toSentenceCase
    addContextFrom
    toLower
    toUpper
    splitStringBy
    flatten
    ;
in
rec {
  capitalise =
    str:
    let
      chars = lib.strings.stringToCharacters str;
      firstChar = head chars;
      remainingChars = tail chars;
    in
    concatStringsSep "" ([ (toUpper firstChar) ] ++ remainingChars);

  /*
    Splits a formatted string into its component parts based on common word boundaries.
    For example:
    - "HelloWorld" -> [ "Hello", "World" ]
    - "hello_world" -> [ "hello", "world" ]
    - "hello-world" -> [ "hello", "world" ]
    - "hello world" -> [ "hello", "world" ]
  */
  splitFormattedString =
    str:
    let
      separators = splitStringBy (
        _prev: curr:
        elem curr [
          "-"
          "_"
          " "
        ]
      ) false str;
      parts =
        map (
          str: splitStringBy (prev: curr: match "[a-z]" prev != null && match "[A-Z]" curr != null) true str
        ) separators
        |> flatten;

      first = if length parts > 0 then toLower (head parts) else "";
      rest = if length parts > 1 then map toSentenceCase (tail parts) else [ ];
    in
    map (addContextFrom str) ([ first ] ++ rest);

  toSnakeCase = str: concatStringsSep "_" (map toLower (splitFormattedString str));

  toKebabCase = str: concatStringsSep "-" (map toLower (splitFormattedString str));

  # True when a string looks like a credential rather than a path or a plain value.
  looksLikeCredential =
    value:
    match "eyJ[A-Za-z0-9_-]{8,}\\..*" value != null
    || match "sk-[A-Za-z0-9_-]{16,}" value != null
    || match "[0-9a-f]{32}" value != null
    || match "gh[pousr]_[A-Za-z0-9]{20,}" value != null;
}
