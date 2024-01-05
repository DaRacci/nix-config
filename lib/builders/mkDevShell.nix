{ system
, name
, pkgsFor
, ...
}:
let
  pkgs = pkgsFor.${system};
in
pkgs.mkShell {
  inherit name;

  nativeBuildInputs = with pkgs; [
    # Cli Tools
    act # For Github Action testing
    hyperfine # For benchmarking
    cocogitto # For Conventional Commits
  ];
}
