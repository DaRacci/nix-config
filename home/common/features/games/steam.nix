{ config, pkgs, lib, ... }: {
  home.file.".config/steam-flags-blocklist.conf".text = ''
    --disable-gpu
    --disable-gpu-compositing
    --use-angle=gl
    --disable-smooth-scrolling
  '';

  home.file.".config/steam-flags.conf".text = ''
    --ignore-gpu-blocklist
    --disable-frame-rate-limit
    --enable-gpu-rasterization
    --enable-features=VaapiVideoDecoder
    --use-gl=desktop
    --enable-zero-copy
  '';

  # # Applies a fix to the run script that allows gpu acceleration to work on nvidia
  # # Source https://github.com/ValveSoftware/steam-for-linux/issues/8918#issuecomment-1574456384
  home.activation.steam-fixer =
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
    lib.hm.dag.entryAfter [ "writeBoundry" ] ''
      fix () {
        echo "Applying steam fixer"
        sed 's,exec "$@",${fixString},g' -i '${file}'
        echo '${actualFix}' >> '${file}'
      }

      # Test if the file exists
      if [ -f '${file}' ]; then
        # Test if the file contains the fix string
        if grep -q '${fixString}' '${file}'; then
          # If the file contains the fix, do nothing
          echo "Steam fixer already applied"
        else
          # If the file does not contain the string, add it
          fix
        fi;
      else
        # If the file does not exist, create and fix it
        cp '${remoteArchive.outPath}/templates/run.sh' '${file}'
        fix
      fi;
    '';

  home.packages = with pkgs; [ steamtinkerlaunch ];

  user.persistence.directories = [
    ".local/share/Steam"
    ".config/steamtinkerlaunch"

    # Games
    ".barony"
    ".local/share/Colossal Order/Cities_Skylines"
  ];

  # TODO :: Force restart steam on rebuild if its open
  # TODO :: Block switch if steam has game open
}
