{
  self,
  inputs,
  ...
}:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages = lib.mine.attrsets.recursiveMergeAttrs [
        (import "${self}/pkgs" { inherit inputs pkgs lib; })
        (import "${self}/flake/ci/scripts" { inherit inputs pkgs lib; })
        (import "${self}/flake/dev/scripts" { inherit inputs pkgs lib; })
      ];
    };
}
