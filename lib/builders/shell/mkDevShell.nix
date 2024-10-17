{ pkgs
, name
, ...
}: pkgs.mkShell {
  inherit name;

  NIX_CONFIG = "extra-experimental-features = nix-command flakes";

  nativeBuildInputs = with pkgs; [
    # Cli Tools
    act # For Github Action testing
    hyperfine # For benchmarking
    cocogitto # For Conventional Commits
  ];
}
