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
  serverHosts = hostsByType.server or [ ];

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
      monitoringPrimaryHost = "nixmon";
      distributedBuilders = [ "nixserv" ];
    };
  };

  flake = {
    nixosConfigurations = genAttrs hostNames (
      hostName:
      mkSystem hostName {
        inherit self inputs;
        inherit (config) allocations;
        deviceType =
          hostsByType
          |> filterAttrs (_: v: elem hostName v)
          |> attrNames
          |> head;
        deviceUsers = userHosts |> filterAttrs (_: v: elem hostName v) |> attrNames;
      }
    );

    nixosTestConfigurations =
      let
        builder = import "${self}/tests/builder.nix";
        inherit (config.partitions.nixos.module) allocations;
      in
      builtins.listToAttrs (
        map (
          hostName:
          let
            hostSystem =
              self.nixosConfigurations.${hostName}.config.nixpkgs.hostPlatform
                or self.nixosConfigurations.${hostName}.pkgs.stdenv.hostPlatform.system;
            hostPkgs = lib.builders.mkPkgs { system = hostSystem; };
          in
          lib.nameValuePair hostName (builder {
            inherit
              self
              inputs
              lib
              allocations
              hostName
              ;
            pkgs = hostPkgs;
            testUnits = self.nixosConfigurations.${hostName}.config.server.tests.units or { };
          })
        ) serverHosts
      )
      // (
        let
          scenariosDir = "${self}/tests/scenarios";
        in
        if builtins.pathExists scenariosDir then
          builtins.listToAttrs (
            map (
              scenarioName:
              lib.nameValuePair scenarioName (builder {
                inherit
                  self
                  pkgs
                  lib
                  ;
                scenario = (import "${scenariosDir}/${scenarioName}/test.nix") // {
                  name = scenarioName;
                };
              })
            ) (builtins.attrNames (lib.filterAttrs (_: v: v == "directory") (builtins.readDir scenariosDir)))
          )
        else
          { }
      );
  };
}
