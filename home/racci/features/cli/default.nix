{ flake, ... }: {
  imports = [
    "${flake}/home/shared/features/cli"
    ./git.nix
  ];
}
