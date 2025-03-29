{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.user.autorun;

  packageDefinition =
    { name, config, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          example = "1password";
          description = ''
            Name of the service.

            Inherited from the package attribute name by default.
          '';
        };

        slice = mkOption {
          type = types.enum [
            "app-graphical"
            "background"
            "background-graphical"
          ];
          default = "app-graphical";
          example = "app-graphical";
          description = ''
            Slice to run the service in.
          '';
        };

        package = mkOption {
          type = types.package;
          default = null;
          example = pkgs._1password-gui;
          description = ''
            Package to be started automatically.
          '';
        };

        extraArgs = mkOption {
          type = with types; listOf str;
          default = "";
          example = "--silent";
          description = ''
            Extra arguments to pass to the service.
          '';
        };

        executablePath = mkOption {
          type = types.str;
          default = lib.getExe config.package;
          example = "${pkgs._1password-gui}/bin/1password";
          description = ''
            Path to the executable.

            If lib.getExe does not find the correct executable, you can override this option.
          '';
        };
      };
    };
in
{
  options.user.autorun = {
    enable = (mkEnableOption "Enable autorun services") // {
      default = true;
    };

    services = mkOption {
      type = with types; attrsOf (submodule packageDefinition);
      default = { };
      description = ''
        List of services to be started automatically.
      '';
    };
  };

  config = mkIf (cfg.enable && builtins.length (lib.attrNames cfg.services) > 0) {
    assertions =
      (map (service: {
        assertion = builtins.pathExists service.executablePath;
        message = "Executable path does not exist: ${service.executablePath}";
      }))
        (lib.attrValues cfg.services);

    systemd.user.services = mapAttrs' (
      _name: service:
      nameValuePair "autoRun--${service.name}" {
        Unit = {
          Description = "Auto-Run ${service.name} at Login.";
          After = [ config.wayland.systemd.target ];
          PartOf = [ config.wayland.systemd.target ];
        };

        Service = {
          PassEnvironment = [ "DISPLAY" ];
          ExecStart = "${service.executablePath} ${concatStringsSep " " service.extraArgs}";
          Slice = service.slice;
        };

        Install.WantedBy = [ config.wayland.systemd.target ];
      }
    ) cfg.services;
  };
}
