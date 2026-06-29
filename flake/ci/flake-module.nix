{
  self,
  inputs,
  lib,
  ...
}:
let
  action-lib = inputs.nix-github-actions.lib;
in
{
  flake = {
    githubActions = action-lib.mkGithubMatrix {
      checks = lib.mine.attrsets.recursiveMergeAttrs [
        self.checks
      ];
    };
  };
}
