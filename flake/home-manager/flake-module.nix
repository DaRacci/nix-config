{
  self,
  lib,
  ...
}:
let
  inherit (lib) nameValuePair;
  inherit (lib.builders) readDirNoCommons;
in
{
  flake.homeConfigurations =
    readDirNoCommons "${self}/home"
    |> builtins.filter (user: builtins.pathExists "${self}/home/${user}/hm-config.nix")
    |> builtins.map (user: nameValuePair user (lib.builders.home.mkHomeManager user { inherit self; }))
    |> builtins.listToAttrs;
}
