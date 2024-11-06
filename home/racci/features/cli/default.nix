{ flake, ... }: {
  imports = [
    "${flake}/home/shared/features/cli"
    ./cava.nix
    ./fastfetch.nix
    ./git.nix
  ];

  user.persistence.directories = [
    ".terraform.d"
  ];
}
