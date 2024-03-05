{ system, pkgsFor, ... }:
let pkgs = pkgsFor system; inherit (pkgs) lib; in {
  /* Recursively merge a list of attrsets into a single attrset.

    nix-repl> recursiveMergeAttrs [ { a = "foo"; } { b = "bar"; } ];
    { a = "foo"; b = "bar"; }
    nix-repl> mergeAttrsetsList [ { a.b = "foo"; } { a.c = "bar"; } ]
    { a = { b = "foo"; c = "bar"; }; }
  */
  recursiveMergeAttrs = lib.foldl' lib.recursiveUpdate { };

  ifTheyExist = attrs: possible_attrs: builtins.filter (attr: builtins.hasAttr attr attrs) possible_attrs;
}
