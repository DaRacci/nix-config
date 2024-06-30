# TODO - Force restart steam on rebuild if its open
# TODO - Block switch if steam has game open
{ config, pkgs, lib, ... }: with lib;
let cfg = config.purpose.gaming.steam; in {
  options.purpose.gaming.steam =
    {
      enable = mkEnableOption "Steam";
      enableNvidiaPatches = (mkEnableOption "Enable Nvidia patches") // {
        description = ''
          Enabled a script which applies a patch to the steam runtime shel file to allow gpu acceleration on nvidia cards.
        '';
      };
      # TODO
      enableProtonUpdates = (mkEnableOption "Automatically update Proton") // {
        description = ''
          If enabled, Proton will be automatically updated and have the latest version symlinked to steam store.

          This is done using the tool `protonup-rs`.
        '';
      };
    };

  config = mkIf cfg.enable
    {
      home = {
        #region - Fix Big Picture Mode on Nvidia
        file = {
          ".config/steam-flags-blocklist.conf" = {
            text = ''
              --disable-gpu
              --disable-gpu-compositing
              --use-angle=gl
              --disable-smooth-scrolling
            '';
          };

          ".config/steam-flags.conf" = mkIf cfg.enableNvidiaPatches {
            text = ''
              --ignore-gpu-blocklist
              --disable-frame-rate-limit
              --enable-gpu-rasterization
              --enable-features=VaapiVideoDecoder
              --use-gl=desktop
              --enable-zero-copy
            '';
          };
        };

        # Applies a fix to the run script that allows gpu acceleration to work on nvidia
        # Implemented from https://github.com/ValveSoftware/steam-for-linux/issues/8918#issuecomment-1574456384
        activation.steam-fixer =
          let
            file = "${config.home.homeDirectory}/.local/share/Steam/ubuntu12_64/steam-runtime-heavy/run.sh";
            fixString = "# CFG FIX BELOW";
            remoteArchive = fetchGit {
              url = "https://github.com/ValveSoftware/steam-runtime.git";
              ref = "master";
            };
            actualFix = ''
              # Not steamwebhelper so skip
              if [[ "$1" != *steamwebhelper* ]]; then
                exec "$@"
                exit
              fi

              args=()

              # Read blocklist from ~/.config/steam-flag-blocklist.conf
              blocklisted_flags=()
              while read flag; do
                  blocklisted_flags+=("$flag")
              done < "$XDG_CONFIG_HOME/steam-flags-blocklist.conf"

              # Filter arguments using the blocklist
              for arg in "$@"; do
                include_arg=true

                for blocklisted_flag in "''${blocklisted_flags[@]}"; do
                  if [[ "$arg" == "$blocklisted_flag" ]]; then
                    include_arg=false
                  fi
                done

                if $include_arg; then
                  args+=("$arg")
                fi
              done

              # Add additional flags from ~/.config/steam-flags.conf
              while read flag; do
                  args+=("$flag")
              done < "$XDG_CONFIG_HOME/steam-flags.conf"

              # Execute
              echo "''${args[@]}" >> /tmp/steam-args
              exec "''${args[@]}"
            '';
          in
          mkIf cfg.enableNvidiaPatches (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            fix () {
              echo "Applying steam fixer"
              sed 's,exec "$@",${fixString},g' -i '${file}'
              echo '${actualFix}' >> '${file}'
            }

            if [ -f '${file}' ]; then
              echo "Steam runtime found"
              if grep -q '${fixString}' '${file}'; then
                echo "Steam fixer already applied"
              else
                fix
              fi;
            else
              cp '${remoteArchive.outPath}/templates/run.sh' '${file}'
              fix
            fi;
          '');
        #endregion - Fix Big Picture Mode on Nvidia

        #region - Fix download speed issues
        # Line 1: Disables HTTP/2
        # Line 2: Allows concurrent server connections
        file.".local/share/steam/steam-dev.cfg".text = ''
          @nClientDownloadEnableHTTP2PlatformLinux 0
          @fDownloadRateImprovementToAddAnotherConnection 1.0
        '';
        #endregion - Fix download speed issues

        packages = with pkgs; [ protonup-rs ];
      };

      user.persistence.directories = [
        ".local/share/Steam"
        ".config/steamtinkerlaunch"

        # Games
        ".barony"
        ".local/share/Colossal Order/Cities_Skylines"
        ".config/WarThunder"
        ".config/Gaijin"
      ];
    };
}
