{ pkgs }:
{
  # Modding
  ficsit-cli = pkgs.callPackage ./ficsit-cli { };

  # VR Stuff
  alvr = pkgs.callPackage ./alvr { };

  # Racing Games
  monocoque = pkgs.callPackage ./monocoque { };

  new-host = pkgs.callPackage ./helpers/new-host.nix { };
}
