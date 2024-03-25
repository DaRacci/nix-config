{ config, pkgs, lib, ... }: with lib; let
  cfg = config.user.autorun;

  packageDefinition = { name, config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
        example = "1password";
        description = ''
          Name of the service.
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
        default = "${config.package}/bin/${config.name}";
        example = "${pkgs._1password-gui}/bin/1password";
        description = ''
          Path to the executable.
        '';
      };
    };
  };
in {
  options.user.autorun = {
    enable = (mkEnableOption "Enable autorun services") // { default = true; };

    services = mkOption {
      type = with types; attrsOf (submodule packageDefinition);
      description = ''
        List of services to be started automatically.
      '';
    };
  };

  config = mkIf cfg.enable {
    # assertions = (map (service: {
    #   assertion = builtins.pathExists service.executablePath;
    #   message = "Executable path does not exist: ${service.executablePath}";
    # })) cfg.services;

    systemd.user.services = (mapAttrs' (_name: service: nameValuePair "autoRun--${service.name}" {
      Unit = {
        Description = "Auto-Run ${service.name} at Login.";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        PassEnvironment = [ "DISPLAY" ];
        ExecStart = "${service.executablePath} ${concatStringsSep " " service.extraArgs}";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    }) cfg.services);
  };
}