{ flake, ... }: {
  imports = [
    ./features/desktop/gnome.nix

    ./features/cli
    "${flake}/home/shared/features/games"
    "${flake}/home/shared/applications"
  ];
}
