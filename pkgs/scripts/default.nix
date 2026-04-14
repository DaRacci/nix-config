{
  pkgs,
  lib,
}:
let
  inherit (lib.mine.packages) writeNuApplication;
in
{
  folder-diff = writeNuApplication {
    inherit pkgs;
    sourceRoot = ./.;
    name = "folder-diff";
    runtimeInputs = [
      pkgs.rsync
      pkgs.uutils-findutils
    ];
  };
}
