{ flake, ... }: {
  imports = [
    "${flake}/home/shared/features/cli"
    ./cava.nix
    ./fastfetch.nix
    ./git.nix
    ./multiplexer.nix
  ];

  user.persistence.directories = [
    ".terraform.d"
  ];
}
