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
}
