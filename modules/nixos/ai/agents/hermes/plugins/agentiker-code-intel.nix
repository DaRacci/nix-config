{
  config,
  pkgs,
  lib,
  ...
}:
(import ../lib.nix { inherit lib; }).mkPluginModule config {
  name = "agentiker-code-intel";
  extraPackages = [
    pkgs.ast-grep
    pkgs.tree-sitter
  ];
  extraPythonPackages = [
    config.services.hermes-agent.package.python.pkgs.tree-sitter
    config.services.hermes-agent.package.python.pkgs.ast-grep-py
  ];
  extraPluginSrc = pkgs.fetchFromGitHub {
    name = "agentiker-code-intel";
    owner = "IVRZ-da";
    repo = "agentiker-code-intel";
    rev = "v0.6.13";
    hash = "sha256-DEKSe1mrN0KNK0JrzlPJL6tNIjQ9COARD0ddrkHISlk=";
  };
}
