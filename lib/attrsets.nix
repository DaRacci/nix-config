{ lib, ... }:
{
  /*
    Recursively merge a list of attrsets into a single attrset.

    nix-repl> recursiveMergeAttrs [ { a = "foo"; } { b = "bar"; } ];
    { a = "foo"; b = "bar"; }
    nix-repl> mergeAttrsetsList [ { a.b = "foo"; } { a.c = "bar"; } ]
    { a = { b = "foo"; c = "bar"; }; }
  */
  recursiveMergeAttrs = lib.foldl' lib.recursiveUpdate { };

  # Given a set of attribute values, return the set of the corresponding attributes from the given set.
  getAttrsByValue =
    values: attrs:
    lib.pipe values [
      (lib.map (value: lib.attrNames (lib.filterAttrs (_: attr: attr == value) attrs)))
      lib.concatLists
    ];

  /*
    Filter a list of attributes to only include those that exist in a given set of attributes.

    nix-repl> filterAttrsIfTheyExist { a = 1; b = 2; } [ "a" "c" ];
    [ "a" ]
  */
  ifTheyExist =
    attrs: possible_attrs: builtins.filter (attr: builtins.hasAttr attr attrs) possible_attrs;
}
