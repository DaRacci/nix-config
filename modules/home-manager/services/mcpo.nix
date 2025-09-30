{
  self,
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit
    (import "${self}/modules/nixos/services/mcpo.nix" {
      inherit
        inputs
        config
        pkgs
        lib
        ;
    })
    options
    ;
  cfg = config.services.mcpo;
in
{
  options.services.mcpo = options.services.mcpo;

  config = lib.mkIf cfg.enable {
    sops.templates = {
      mcpoConfiguration.content = builtins.toJSON { mcpServers = cfg.configuration; };
      mcpoEnvironment.content = lib.toShellVars cfg.environment;
    };

    systemd.user.services.mcpo = {
      Unit = {
        After = [ "network.target" ];
        X-Restart-Triggers = [
          config.sops.templates.mcpoConfiguration.path
          config.sops.templates.mcpoEnvironment.path
        ];
      };

      Service = {
        EnvironmentFile = config.sops.templates.mcpoEnvironment.path;
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "PATH=${
            lib.makeBinPath (
              with pkgs;
              [
                bash
                toybox
                nodejs
                uv
              ]
              ++ cfg.extraPackages
            )
          }"
        ];

        ExecStart =
          (import "${inputs.nixpkgs}/nixos/lib/utils.nix" { inherit lib config pkgs; })
          .systemdUtils.lib.makeJobScript
            {
              enableStrictShellChecks = false;
              name = "mcpo-start";
              text =
                [
                  (lib.getExe cfg.package)
                  "--hot-reload"
                  "--port"
                  "8182"
                  "--config \"${config.sops.templates.mcpoConfiguration.path}\""
                  (lib.optionalString (cfg.apiTokenFile != null)
                    "--api-key $(cat \"${config.sops.secrets."MCP/API_TOKEN".path}\")"
                  )
                ]
                |> builtins.filter (v: v != "")
                |> lib.concatStringsSep " ";
            };
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
