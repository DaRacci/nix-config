{ lib }:
let
  inherit (builtins)
    concatStringsSep
    filter
    length
    ;
in
{
  unique =
    { values }:
    let
      duplicates = lib.unique (filter (value: length (filter (other: other == value) values) > 1) values);
    in
    [
      {
        assertion = duplicates == [ ];
        message = "duplicate ${concatStringsSep ", " (map toString duplicates)}";
      }
    ];

  range =
    {
      min,
      max,
      values,
    }:
    let
      invalid = filter (value: value < min || value > max) values;
    in
    [
      {
        assertion = invalid == [ ];
        message = "out of range ${concatStringsSep ", " (map toString invalid)}";
      }
    ];

  keys =
    { expected, actual }:
    let
      missing = lib.subtractLists actual expected;
      stale = lib.subtractLists expected actual;
    in
    [
      {
        assertion = missing == [ ];
        message = "missing ${concatStringsSep ", " missing}";
      }
      {
        assertion = stale == [ ];
        message = "stale ${concatStringsSep ", " stale}";
      }
    ];
}
