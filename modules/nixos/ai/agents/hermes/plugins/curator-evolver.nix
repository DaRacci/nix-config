{
  config,
  pkgs,
  lib,
  ...
}: let
  hlib = import ../lib.nix { inherit lib; };
  hermes-curator-evolver = pkgs.hermes-curator-evolver.overridePythonAttrs (base: {
    dependencies = hlib.depsMinusNamed [ "pyyaml" ] base.dependencies;
    dontCheckRuntimeDeps = true;
  });
in hlib.mkPluginModule config {
  name = "curator-evolver";
  extraPackages = [ hermes-curator-evolver ];
  extraPythonPackages = [ hermes-curator-evolver ];
}
