{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkEnableOption
    mkOption
    types
    literalExpression
    getExe
    ;

  cfg = config.purpose.diy;
  gitSyncCfg = cfg.printing.gitSync;

  orcaGitSyncScript = pkgs.writeShellApplication {
    name = "orca-slicer-git-sync";
    runtimeInputs = [
      pkgs.git
      pkgs.inotify-tools
    ];
    text = ''
      REPO_DIR="${gitSyncCfg.repoPath}"

      until [ -d "$REPO_DIR" ]; do
        sleep 10
      done

      if [ ! -d "$REPO_DIR/.git" ]; then
        echo "Initializing git repository at $REPO_DIR"
        git -C "$REPO_DIR" init -q
        git -C "$REPO_DIR" add -A
        if ! git -C "$REPO_DIR" diff --cached --quiet 2>/dev/null; then
          git -C "$REPO_DIR" commit -m "chore: initial commit" -q
          echo "Created initial commit"
        fi
      fi

      ${lib.optionalString (gitSyncCfg.enable && gitSyncCfg.remoteUrl != null) ''
        if ! git -C "$REPO_DIR" remote get-url origin 2>/dev/null | grep -q "${gitSyncCfg.remoteUrl}"; then
          git -C "$REPO_DIR" remote remove origin 2>/dev/null || true
          git -C "$REPO_DIR" remote add origin "${gitSyncCfg.remoteUrl}" 2>/dev/null || true
          echo "Configured remote: ${gitSyncCfg.remoteUrl}"
        fi
      ''}

      commit_changes() {
        local status
        status=$(git -C "$REPO_DIR" status --porcelain 2>/dev/null) || return 0
        [ -z "$status" ] && return 0
        echo "Changes detected, preparing commit..."

        while IFS= read -r line; do
          [ -z "$line" ] && continue

          local xy filepath
          xy="''${line:0:2}"
          filepath="''${line:3}"
          if [[ "$filepath" == *" -> "* ]]; then
            filepath="''${filepath##* -> }"
          fi
          # git quotes filenames containing special characters (spaces, @, &, etc.)
          # strip surrounding double-quotes if present
          filepath="''${filepath#\"}"
          filepath="''${filepath%\"}"
          echo "Processing change: $xy $filepath"

          # Derive the profile type from the first directory component.
          # Files at the repo root (no slash) fall back to "config".
          local type
          if [[ "$filepath" == */* ]]; then
            type="''${filepath%%/*}"
          else
            type="config"
          fi
          echo "Determined type: $type"

          local basename_file name
          basename_file="$(basename "$filepath")"
          name="''${basename_file%.*}"
          echo "Determined name: $name"

          local msg
          local x="''${xy:0:1}"
          local y="''${xy:1:1}"
          if [[ "$xy" == "??" ]] || [[ "$x" == "A" ]] || [[ "$y" == "A" ]]; then
            msg="feat($type): added $name"
          elif [[ "$x" == "D" ]] || [[ "$y" == "D" ]]; then
            msg="chore($type): removed $name"
          else
            msg="refactor($type): updated $name"
          fi
          echo "Determined commit message: $msg"

          git -C "$REPO_DIR" add -A
          if ! git -C "$REPO_DIR" diff --cached --quiet 2>/dev/null; then
            git -C "$REPO_DIR" commit -m "$msg" -q
            echo "Committed: $msg"

            ${lib.optionalString (gitSyncCfg.enable && gitSyncCfg.remoteUrl != null) ''
              if git -C "$REPO_DIR" push -q "${gitSyncCfg.remoteUrl}" 2>/dev/null; then
                echo "Pushed to remote: ${gitSyncCfg.remoteUrl}"
              else
                echo "Warning: Failed to push to remote ${gitSyncCfg.remoteUrl}"
              fi
            ''}
          fi
        done <<< "$status"
      }

      echo "Starting OrcaSlicer git sync watcher for $REPO_DIR"

      # Use inotifywait in one-shot mode inside a loop so that after each
      # event we can sleep briefly to batch rapid filesystem activity before
      # committing all accumulated changes.
      while true; do
        if inotifywait -r -q \
            -e close_write -e create -e delete -e moved_to -e moved_from \
            --exclude '\.git' \
            "$REPO_DIR" 2>/dev/null; then
          echo "Filesystem change detected, processing git commit..."
          sleep 2
          commit_changes
        else
          # inotifywait failed (e.g. directory was temporarily unavailable);
          # pause before retrying so we do not spin
          sleep 5
        fi
      done
    '';
  };
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
        pkgs.orca-slicer-zink
        pkgs.lycheeslicer
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
          ExecStart = getExe orcaGitSyncScript;
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
