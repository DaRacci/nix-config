{
  self,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.builders) readDirNoCommons;

  accelerationHosts = {
    cuda = [
      "nixmi"
    ];
    rocm = [
      # "nixai"
    ];
  };

  hosts =
    readDirNoCommons "${self}/hosts"
    |> builtins.map (
      deviceType: lib.nameValuePair deviceType (readDirNoCommons "${self}/hosts/${deviceType}")
    )
    |> builtins.listToAttrs;
  hostNames = hosts |> builtins.attrValues |> lib.flatten;

  userHosts =
    readDirNoCommons "${self}/home"
    |> builtins.map (
      user:
      lib.nameValuePair user (
        readDirNoCommons "${self}/home/${user}"
        |> builtins.map (file: lib.removeSuffix ".nix" file)
        |> builtins.filter (rootFile: builtins.elem rootFile hostNames)
      )
    )
    |> lib.flatten
    |> builtins.listToAttrs;
in
{
  flake = {
    nixosConfigurations =
      hosts
      |> lib.mapAttrsToList (
        deviceType: hostNames:
        builtins.map (
          hostName:
          lib.nameValuePair hostName {
            inherit deviceType;
            users = userHosts |> lib.filterAttrs (_: v: builtins.elem hostName v) |> builtins.attrNames;
            accelerators =
              accelerationHosts |> lib.filterAttrs (_: v: builtins.elem hostName v) |> builtins.attrNames;
          }
        ) hostNames
      )
      |> lib.flatten
      |> builtins.listToAttrs
      |> builtins.mapAttrs (
        hostName: hostAttrs: lib.builders.mkSystem hostName (hostAttrs // { inherit self inputs; })
      );
  };
}
