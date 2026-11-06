{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.mine.packages) writeNuApplicationWithLibs;
  sourceRoot = ./.;
in
{
  archive-flakes = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "archive-flakes";
  };

  create-pr = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "create-pr";
    runtimeInputs = [
      pkgs.curl
      pkgs.gh
      pkgs.jq
    ];
  };

  decide-affected = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "decide-affected";
  };

  devenv-run = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "devenv-run";
  };

  check-upstream-todos = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "check-upstream-todos";
    runtimeInputs = [
      pkgs.curl
      pkgs.gitMinimal
      pkgs.ripgrep
    ];
  };

  detect-affected-outputs = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "detect-affected-outputs";
  };

  discover-packages = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "discover-packages";
    runtimeInputs = [
      pkgs.fd
      pkgs.jq
    ];
  };

  setup-attic = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "setup-attic";
    runtimeInputs = [
      pkgs.bash
      pkgs.attic-client
    ];
  };

  setup-git = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "setup-git";
    runtimeInputs = [
      pkgs.gitMinimal
      pkgs.gnupg
    ];
  };

  update-locks = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "update-locks";
  };

  update-matrix = writeNuApplicationWithLibs {
    inherit pkgs sourceRoot;
    name = "update-matrix";
  };
}
