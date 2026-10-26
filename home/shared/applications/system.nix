{ pkgs, ... }:
let
  inherit (pkgs) resources;
in
{
  home.packages = [
    resources
  ];
}
