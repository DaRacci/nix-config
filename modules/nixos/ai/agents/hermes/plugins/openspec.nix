{
  config,
  pkgs,
  lib,
  ...
}: (import ../lib.nix { inherit lib; }).mkPluginModule config {
  name = "openspec";
  extraPackages = [ pkgs.openspec ];
  extraPluginSrc = pkgs.fetchFromGitHub {
    name = "hermes-openspec";
    owner = "FelineStateMachine";
    repo = "hermes-openspec";
    rev = "493b42cd95d2a30f967ede5a53eb22d1bd248fb9";
    hash = "sha256-opSPs/yX9m5if9KP5qVmBLDYxeuYlidHNrFomTkee+k=";
  };
}
