{
  lib,
  ...
}:
{
  capitalise =
    str:
    let
      chars = lib.strings.stringToCharacters str;
      firstChar = lib.head chars;
      remainingChars = lib.tail chars;
    in
    builtins.concatStringsSep "" ([ (lib.toUpper firstChar) ] ++ remainingChars);
}
