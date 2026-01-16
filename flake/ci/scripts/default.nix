{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.mine.packages) writeNuApplicationWithLibs;
in
{
  create-pr = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "create-pr";
    runtimeInputs = [ pkgs.gh ];
  };

  setup-git = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "setup-git";
    runtimeInputs = [
      pkgs.gitMinimal
      pkgs.gnupg
    ];
  };

  update-locks = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "update-locks";
    runtimeInputs = [ pkgs.nix ];
  };
}
