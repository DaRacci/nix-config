{
  lib,
  ...
}:
let
  inherit (builtins)
    elem
    concatStringsSep
    split
    elemAt
    ;
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
    toInt
    ;

  scalar = 1024;
  sizeTable = rec {
    K = scalar;
    Ki = K;
    M = K * scalar;
    Mi = M;
    G = M * scalar;
    Gi = G;
    T = G * scalar;
    Ti = T;
  };
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
    - "HelloWorld" -> [ "Hello", "World" ] (CamelCase)
    - "hello_world" -> [ "hello", "world" ] (Snake case)
    - "hello-world" -> [ "hello", "world" ] (Kebab case)
    - "hello world" -> [ "hello", "world" ] (Space separated)
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

  parseSize =
    s:
    let
      m = match "^([0-9]+)([KMGT]i?)B?$" s;
    in
    if m == null then
      throw "Invalid size format: ${toString s}"
    else
      let
        num = toInt (elemAt m 0);
        unit = elemAt m 1;
        multiplier = sizeTable.${unit} or (throw "Unknown size unit: ${unit}");
      in
      num * multiplier;
}
