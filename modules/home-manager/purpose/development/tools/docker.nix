{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.purpose.development.tools.docker;
  rootCfg = config.purpose.development;
in
{
  options.purpose.development.tools.docker = {
    enable = mkEnableOption "Enable Docker Development Tools";
  };

  config = mkIf (rootCfg.enable && cfg.enable) {
    home.packages = [
      pkgs.docker-client
      pkgs.docker-buildx
      pkgs.docker-compose
      pkgs.docker-credential-helpers
      pkgs.dive
    ];

    programs.docker-cli = {
      enable = true;
      settings = {
        credsStore = "secretservice";
        auths."registry.racci.dev" = { };
      };
    };
  };
}
