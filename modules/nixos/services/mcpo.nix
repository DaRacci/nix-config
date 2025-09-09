{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.mcpo;

  npx = lib.getExe' pkgs.nodejs "npx";
  uvx = lib.getExe' pkgs.uv "uvx";

  helpers = rec {
    npxServer = package: {
      command = npx;
      args = [
        "-y"
        package
      ];
    };
    npxServerWithArgs =
      package: args:
      let
        base = npxServer package;
      in
      base
      // {
        args = base.args ++ args;
      };

    uvxServer = package: {
      command = uvx;
      args = [ package ];
    };
    uvxServerWithArgs =
      package: args:
      let
        base = uvxServer package;
      in
      base
      // {
        args = base.args ++ args;
      };
  };
in
{
  options.services.mcpo = with lib.types; {
    enable = lib.mkEnableOption "mcpo (Model Context Protocol Orchestrator) service";

    package = lib.mkOption {
      type = package;
      default = with pkgs.python3Packages; toPythonApplication pkgs.mcpo;
      description = "Package providing the mcpo executable.";
    };

    configuration = lib.mkOption {
      type = attrsOf (submodule {
        options = {
          command = lib.mkOption {
            type = nullOr str;
            default = null;
            description = "Command to render the config file.";
          };

          args = lib.mkOption {
            type = listOf str;
            default = [ ];
            description = "Arguments to pass to the command.";
          };

          type = lib.mkOption {
            type = nullOr (enum [
              "sse"
              "streamable-http"
            ]);
            default = null;
          };

          url = lib.mkOption {
            type = nullOr str;
            default = null;
          };

          headers = lib.mkOption {
            type = attrsOf str;
            default = { };
            description = "Headers to pass to the command.";
          };
        };
      });
    };

    apiTokenFile = lib.mkOption {
      type = nullOr path;
      default = null;
      description = ''
        Path to a file containing the API token for the mcpo service.
        This file will be exposed to the service through a systemd credential named "apiToken".
      '';
    };

    extraPackages = lib.mkOption {
      type = listOf package;
      default = [ ];
      description = "Additional packages to include in the service's PATH.";
    };

    environment = lib.mkOption {
      type = attrsOf str;
      default = { };
      description = "Additional environment variables for the service.";
    };

    helpers = lib.mkOption {
      type = attrs;
      readOnly = true;
      default = helpers;
      description = "Helper functions for constructing mcpo server command blocks.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.templates = {
      mcpoConfiguration.content = builtins.toJSON { mcpServers = cfg.configuration; };
      mcpoEnvironment.content = lib.toShellVars cfg.environment;
    };

    systemd.services.mcpo = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment.HOME = "/var/lib/mcpo";

      path =
        with pkgs;
        [
          bash
          nodejs
          uv
        ]
        ++ cfg.extraPackages;

      serviceConfig = {
        EnvironmentFile = config.sops.templates.mcpoEnvironment.path;
        WorkingDirectory = "/var/lib/mcpo";
        StateDirectory = "mcpo";
        RuntimeDirectory = "mcpo";
        DynamicUser = true;

        NoNewPrivileges = true;
        ProtectClock = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LoadCredential = [
          "config.json:${config.sops.templates.mcpoConfiguration.path}"
        ]
        ++ lib.optional (cfg.apiTokenFile != null) "apiToken:${cfg.apiTokenFile}";
      };

      restartTriggers = [
        config.sops.templates.mcpoConfiguration.path
      ];

      script =
        [
          (lib.getExe cfg.package)
          "--config \"\${CREDENTIALS_DIRECTORY}/config.json\""
          (lib.optionalString (
            cfg.apiTokenFile != null
          ) "--api-key $(cat \"\${CREDENTIALS_DIRECTORY}/apiToken\")")
        ]
        |> builtins.filter (v: v != "")
        |> lib.concatStringsSep " ";
    };
  };
}
