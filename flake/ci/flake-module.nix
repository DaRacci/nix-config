{
  self,
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib.builders) getHostsByType;
  action-lib = inputs.nix-github-actions.lib;

  clusterHosts = (getHostsByType self).server or [ ];
in
{
  flake = {
    githubActions = action-lib.mkGithubMatrix {
      checks = lib.mine.attrsets.recursiveMergeAttrs [
        self.checks
      ];
    };
  };

  perSystem =
    { pkgs, ... }:
    {
      checks.cluster = import "${self}/tests" {
        inherit self pkgs lib clusterHosts;
        inherit (config.partitions.nixos.module) allocations;
      };
    };
}
