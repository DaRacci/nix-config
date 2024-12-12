{ pkgs }: {
  # Modding
  ficsit-cli = pkgs.callPackage ./ficsit-cli { };

  # VR Stuff
  alvr = pkgs.callPackage ./alvr { };
  oscavmgr = pkgs.callPackage ./oscavmgr { };
  vrcadvert = pkgs.callPackage ./vrcadvert { };

  # Racing Games
  monocoque = pkgs.callPackage ./monocoque { };

  new-host = pkgs.callPackage ./helpers/new-host.nix { };
}
