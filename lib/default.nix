{ lib }:
let
  simpleImport = path: import path { inherit lib; };
in
{
  mine = {
    attrsets = simpleImport ./attrsets.nix;
    files = simpleImport ./files.nix;
    hardware = simpleImport ./hardware.nix;
  };
}
