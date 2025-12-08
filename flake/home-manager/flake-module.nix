{
  self,
  lib,
  ...
}:
let
  inherit (lib.builders) readDirNoCommons;
in
{
  flake.homeConfigurations =
    readDirNoCommons "${self}/home"
    |> builtins.map (
      user: lib.nameValuePair user (lib.builders.home.mkHomeManager user { inherit self; })
    )
    |> builtins.listToAttrs;
}
