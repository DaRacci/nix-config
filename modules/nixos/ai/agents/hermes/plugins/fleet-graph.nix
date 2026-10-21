{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
(import ../lib.nix { inherit lib; }).mkPluginModule config {
  name = "fleet-graph";
  extraPluginSrc = pkgs.stdenv.mkDerivation {
    name = "fleet-graph";
    src = inputs.fleet-graph;
    installPhase = ''
      mkdir -p $out
      cp -r $src/* $out/
    '';
  };
}
