{ lib }: let
  simpleImport = path: import path { inherit lib; };
in
{
  mine = {
    attrsets = simpleImport ./attrsets.nix;
    hardware = simpleImport ./hardware.nix;
    files = simpleImport ./files.nix;
  };
}
