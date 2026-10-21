{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    escapeShellArgs
    getExe
    literalExpression
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionals
    types
    ;

  cfg = config.purpose.diy;
  gitSyncCfg = cfg.printing.gitSync;
  orcaGitSyncCommand = escapeShellArgs (
    [
      (getExe pkgs.orca-slicer-git-sync)
      gitSyncCfg.repoPath
    ]
    ++ optionals (gitSyncCfg.remoteUrl != null) [ gitSyncCfg.remoteUrl ]
  );
in
{
  options.purpose.diy.printing = {
    enable = mkEnableOption "Enable 3D printing support";

    gitSync = {
      enable = mkEnableOption "Auto-commit OrcaSlicer settings changes to a local git repository";

      repoPath = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.config/OrcaSlicer/user/default";
        defaultText = literalExpression ''"''${config.home.homeDirectory}/.config/OrcaSlicer/user/default"'';
        description = ''
          Absolute path to the directory that will be tracked as a git
          repository.  The directory is initialised automatically the first
          time the watcher service starts, so it does not need to exist at
          activation time.

          Defaults to the standard OrcaSlicer per-user profile directory so
          that filament, process, and machine profiles are all captured
          without any additional configuration.
        '';
      };

      remoteUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Optional remote URL to push commits to.
          If set, the git sync service will attempt to push
          commits to this remote after creating them.

          The remote must be configured with appropriate credentials
          (e.g. via SSH keys) for non-interactive authentication.
        '';
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.printing.enable {
      assertions = [
        {
          assertion = cfg.enable;
          message = ''
            You have enabled 3D Printing support but not DIY.
            Ensure that `purpose.diy.enable` is set to true.
          '';
        }
      ];

      home.packages = [
        pkgs.orca-slicer
        pkgs.lycheeslicer
        pkgs.uvtools
      ];

      user.persistence.directories = [
        ".config/OrcaSlicer"
        ".local/share/orca-slicer"
        ".config/LycheeSlicer"
      ];
    })

    (mkIf (cfg.printing.enable && gitSyncCfg.enable) {
      systemd.user.services.orca-slicer-git-sync = {
        Unit = {
          Description = "OrcaSlicer settings git auto-commit watcher";
          After = [ "default.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = orcaGitSyncCommand;
          Restart = "on-failure";
          RestartSec = 10;
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    })
  ];
}
