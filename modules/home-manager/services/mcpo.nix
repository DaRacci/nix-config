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
    (import "${self}/modules/nixos/ai/services/mcpo.nix" {
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
              let
                inherit (pkgs)
                  bash
                  nodejs
                  toybox
                  uv
                  ;
              in
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
              text = ''
                ${lib.optionalString (cfg.apiTokenFile != null) ''
                  export MCPO_API_KEY="$(cat "${config.sops.secrets."MCP/API_TOKEN".path}")"
                  [ -n "$MCPO_API_KEY" ] || { echo "mcpo: API token is empty" >&2; exit 1; }
                ''}
                # Requires overlays/patches/mcpo-api-key-env.patch: without it MCPO_API_KEY is
                # ignored and mcpo starts unauthenticated while the guard above still passes.
                exec ${lib.getExe cfg.package} --hot-reload --host 127.0.0.1 --port 8182 --config "${config.sops.templates.mcpoConfiguration.path}"
              '';
            };
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
