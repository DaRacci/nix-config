{
  config,
  pkgs,
  lib,
  ...
}:
let
  lightpanda = pkgs.stdenv.mkDerivation {
    name = "lightpanda";
    dontUnpack = true;
    src = pkgs.fetchurl {
      url = "https://github.com/lightpanda-io/browser/releases/download/1.0.1/lightpanda-x86_64-linux";
      sha256 = "1z9mpi408rzngc29mw207cm7n1wfnjjfqxsjbmxi1fjibkilf5sm";
    };
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/lightpanda
      chmod +x $out/bin/lightpanda
    '';
    meta.mainProgram = "lightpanda";
  };
in (import ../lib.nix { inherit lib; }).mkPluginModule config {
  name = "lightpanda";
  pluginName = "web-browser";

  extraPackages = [ lightpanda ];
  extraConfig = {
    services.hermes-agent.environment.LIGHTPANDA_DISABLE_TELEMETRY = "true";
  };
}
