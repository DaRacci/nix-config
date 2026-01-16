{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.mine.packages) writeNuApplicationWithLibs;
  libSource = ../../../lib/nu-lib;
  sourceRoot = ./.;
in
{
  archive-flakes = writeNuApplicationWithLibs {
    inherit pkgs libSource sourceRoot;
    name = "archive-flakes";
    runtimeInputs = [ pkgs.nix ];
  };

  create-pr = writeNuApplicationWithLibs {
    inherit pkgs libSource sourceRoot;
    name = "create-pr";
    runtimeInputs = [ pkgs.gh ];
  };

  check-upstream-todos = writeNuApplicationWithLibs {
    inherit pkgs libSource sourceRoot;
    name = "check-upstream-todos";
    runtimeInputs = [
      pkgs.curl
      pkgs.gitMinimal
      pkgs.ripgrep
    ];
  };

  detect-affected-outputs = writeNuApplicationWithLibs {
    inherit pkgs libSource sourceRoot;
  };

  discover-packages = writeNuApplicationWithLibs {
    inherit pkgs libSource sourceRoot;
    name = "discover-packages";
    runtimeInputs = [ ];
  };

  setup-attic = writeNuApplicationWithLibs {
    inherit pkgs libSource sourceRoot;
    name = "setup-attic";
    runtimeInputs = [ pkgs.attic-client ];
  };

  setup-git = writeNuApplicationWithLibs {
    inherit pkgs libSource sourceRoot;
    name = "setup-git";
    runtimeInputs = [
      pkgs.gitMinimal
      pkgs.gnupg
    ];
  };

  update-locks = writeNuApplicationWithLibs {
    inherit pkgs libSource sourceRoot;
    name = "update-locks";
    runtimeInputs = [ pkgs.nix ];
  };
}
