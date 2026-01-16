{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.mine.packages) writeNuApplicationWithLibs;
  libSource = ../../../lib/nu-lib;
in
{
  nix-tree-host = writeNuApplicationWithLibs {
    inherit pkgs libSource;
    sourceRoot = ./.;
    name = "nix-tree-host";
    runtimeInputs = [ pkgs.nix-tree ];
  };

  rebuild-target = writeNuApplicationWithLibs {
    inherit pkgs libSource;
    sourceRoot = ./.;
    name = "rebuild-target";
    runtimeInputs = [ pkgs.nh ];
  };

  update-redis-mappings = writeNuApplicationWithLibs {
    inherit pkgs libSource;
    sourceRoot = ./.;
    name = "update-redis-mappings";
    runtimeInputs = [ pkgs.nix ];
  };
}
