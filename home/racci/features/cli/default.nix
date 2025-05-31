{ self, ... }:
{
  imports = [
    "${self}/home/shared/features/cli"
    ./cava.nix
    ./fastfetch.nix
    ./git.nix
    ./terminal.nix
  ];

  user.persistence.directories = [ ".terraform.d" ];
}
