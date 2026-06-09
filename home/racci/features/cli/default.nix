{ self, ... }:
{
  imports = [
    "${self}/home/shared/features/cli"
    ./cava.nix
    ./fastfetch.nix
    ./terminal.nix
    ./vcs.nix
  ];

  user.persistence.directories = [ ".terraform.d" ];
}
