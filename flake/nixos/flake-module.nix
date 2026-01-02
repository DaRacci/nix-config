{
  self,
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    flatten
    genAttrs
    nameValuePair
    removeSuffix
    ;
  inherit (builtins)
    map
    elem
    head
    filter
    attrNames
    attrValues
    listToAttrs
    ;
  inherit (lib.builders) readDirNoCommons mkSystem getHostsByType;

  hostsByType = getHostsByType self;
  hostNames = hostsByType |> attrValues |> flatten;

  userHosts =
    readDirNoCommons "${self}/home"
    |> map (
      user:
      nameValuePair user (
        readDirNoCommons "${self}/home/${user}"
        |> map (file: removeSuffix ".nix" file)
        |> filter (rootFile: elem rootFile hostNames)
      )
    )
    |> flatten
    |> listToAttrs;
in
{
  allocations = {
    accelerators = {
      nixmi = [ "cuda" ];
      nixai = [ ];
    };

    server = {
      ioPrimaryCoordinator = "nixio";
      distributedBuilders = [ "nixserv" ];
    };
  };

  flake = {
    nixosConfigurations = genAttrs hostNames (
      hostName:
      mkSystem hostName {
        inherit self inputs;
        inherit (config) allocations;
        deviceType = hostsByType |> filterAttrs (_: v: elem hostName v) |> attrNames |> head;
        deviceUsers = userHosts |> filterAttrs (_: v: elem hostName v) |> attrNames;
      }
    );
  };
}
