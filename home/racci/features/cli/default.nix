{ flake, ... }: {
  imports = [
    "${flake}/home/common/features/cli"
    ./git.nix
  ];
}
