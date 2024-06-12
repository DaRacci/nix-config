{ flake, ... }: {
  imports = [
    "${flake}/home/shared/features/cli"
    ./git.nix
  ];

  user.persistence.directories = [
    ".terraform.d"
  ];
}
