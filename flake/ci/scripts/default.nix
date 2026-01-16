{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.mine.packages) writeNuApplicationWithLibs;
in
{
  archive-flakes = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "archive-flakes";
    runtimeInputs = [ pkgs.nix ];
  };

  create-pr = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "create-pr";
    runtimeInputs = [ pkgs.gh ];
  };

  check-upstream-todos = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "check-upstream-todos";
    runtimeInputs = [
      pkgs.curl
      pkgs.gitMinimal
      pkgs.ripgrep
    ];
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
