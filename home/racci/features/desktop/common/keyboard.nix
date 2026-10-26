{ pkgs, ... }:
let
  inherit (pkgs) keypunch vial wootility;
in
{
  home.packages = [
    keypunch
    vial
    wootility
  ];
}
