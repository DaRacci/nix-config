{
  config,
  pkgs,
  lib,
  ...
}: (import ../lib.nix { inherit lib; }).mkPluginModule config {
  name = "rtk-rewrite";
  extraPackages = [ pkgs.rtk ];
  extraPythonPackages = [ pkgs.rtk-hermes ];
}
