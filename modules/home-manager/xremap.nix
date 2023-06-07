{ pkgs, ... }:

let
  fullConfig = {
    config = {
      server = {
        commands = {
          serverRestart = ''
            systemctl restart octoprint
          '';
        };
      };
    };
    services = {
      octoprint = {
        enable = true;
        port = 5000;
        config = cfg;
      };
    };
  };
  cfg = pkgs.writeText "octoprint-config.yaml" (builtins.toJSON fullConfig);
in {
  home.file.".config/octoprint-config.yaml".source = "${cfg.outPath}";
}

{ lib, pkgs, config, ... }:

with lib; let
  cfg = config.services.xremap;
in {
  options.services.xremap = {
    enable = mkEnableOption "xremap";
    
    config = mkOption {
      type = with types; attrsOf (attrsOf anything)
      default = { };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.xremap ];

    


    systemd.services.hello = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.hello}/bin/hello -g'Hello, ${escapeShellArg cfg.greeter}!'";
    };
  };
}