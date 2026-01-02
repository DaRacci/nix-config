{
  inputs,
  lib,
  ...
}:
let
  inherit (lib)
    all
    isList
    isAttrs
    flatten
    ;

  simpleImport = path: import path { inherit inputs lib; };
in
{
  mine = {
    attrsets = simpleImport ./attrsets.nix;
    files = simpleImport ./files.nix;
    hardware = simpleImport ./hardware.nix;
    keys = simpleImport ./keys.nix;
    hypr = simpleImport ./hypr.nix;
    strings = simpleImport ./strings.nix;

    mkPostgresRolePass = role: passPath: ''
      psql -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('${passPath}'), E'\n', '''));
          EXECUTE format('ALTER USER "${role}" WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
    '';
  };

  builders = import ./builders { inherit inputs lib; };

  /*
    Filters an input list to items that are not null,
    empty list or an empty attribute set.
  */
  filterEmpty =
    list:
    list
    |> builtins.filter (
      i:
      if isList i then
        i != [ ]
      else if isAttrs i then
        i != { }
      else
        i != null
    );

  /*
    Join a list of items.

    If the list contains attribute sets, they are merged into a single attribute set using `recursiveMergeAttrs`.
    If the list contains lists, they are concatenated into a single list.
  */
  joinItems =
    list:
    if all isAttrs list then
      lib.mine.attrsets.recursiveMergeAttrs list
    else if all isList list then
      flatten list
    else
      throw "joinItems: mixed item types in list, all items must be either attribute sets or lists.";
}
