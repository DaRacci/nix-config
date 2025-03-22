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

  /*
    Merges list of records, concatenates arrays, if two values can't be merged - the latter is preferred

    Example 1:
      recursiveMerge [
        { a = "x"; c = "m"; list = [1]; }
        { a = "y"; b = "z"; list = [2]; }
      ]

      returns

      { a = "y"; b = "z"; c="m"; list = [1 2] }

    Example 2:
      recursiveMerge [
        {
          a.a = [1];
          a.b = 1;
          a.c = [1 1];
          boot.loader.grub.enable = true;
          boot.loader.grub.device = "/dev/hda";
        }
        {
          a.a = [2];
          a.b = 2;
          a.c = [1 2];
          boot.loader.grub.device = "";
        }
      ]

      returns

      {
        a = {
          a = [ 1 2 ];
          b = 2;
          c = [ 1 2 ];
        };
        boot = {
          loader = {
            grub = {
              device = "";
              enable = true;
            };
          };
        };
      }
  */
  recursiveMerge =
    attrList:
    let
      f =
        attrPath:
        builtins.zipAttrsWith (
          n: values:
          if builtins.tail values == [ ] then
            builtins.head values
          else if builtins.all builtins.isList values then
            lib.unique (builtins.concatLists values)
          else if builtins.all builtins.isAttrs values then
            f (attrPath ++ [ n ]) values
          else
            builtins.last values
        );
    in
    f [ ] attrList;
}
