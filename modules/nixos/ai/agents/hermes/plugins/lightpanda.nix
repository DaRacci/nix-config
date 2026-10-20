{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: (import ../lib.nix { inherit lib; }).mkPluginModule config {
  name = "lightpanda";
  pluginName = "web-browser";

  extraPackages = [
    inputs.lightpanda.packages.${pkgs.stdenv.hostPlatform}.lightpanda
  ];

  extraConfig = {
    services.hermes-agent.environment.LIGHTPANDA_DISABLE_TELEMETRY = "true";
  };
}
