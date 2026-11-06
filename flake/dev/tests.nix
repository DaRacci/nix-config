{
  config,
  lib,
  ...
}:
let
  mkTests =
    system:
    import ../../tests {
      inherit lib;
      pkgs = lib.builders.mkPkgs { inherit system; };
    };
in
{
  flake.tests = lib.genAttrs config.systems mkTests;
}
