{
  stdenv,
  lib,

  mkWindowsAppNoCC,
  fetchzip,

  makeDesktopItem,
  copyDesktopItems,

  wine,
  icoextract,
  imagemagick,
}:
mkWindowsAppNoCC rec {
  inherit wine;

  pname = "take-control-viewer";
  version = "7.44.07";

  src = fetchzip {
    url = "https://swi-rc.cdn-sw.net/logicnow/linux_viewer/${version}/LinuxNSight.zip";
    hash = "sha256-u/dcgl/9VP9ifhAmAhdbsrinDgDRBZ1NWVWeV3k3OYg=";
  };

  nativeBuildInputs = [
    copyDesktopItems

    icoextract
    imagemagick
  ];

  wineArch = "win32";
  fileMap = {
    "$HOME/.local/share/take-control-viewer" = "drive_c/users/$USER/AppData/Local/Take Control Viewer";
  };

  graphicsDriver = "wayland";
  enableVulkan = true;

  # Helper shell function:
  # is_descendant <child-pid> <ancestor-pid>
  # returns 0 if <child-pid> is the same as or a descendant of <ancestor-pid>, 1 otherwise.
  #
  # Implementation notes:
  # - Walks the parent chain via /proc/<pid>/status extracting PPid.
  # - Treats missing /proc entries as non-descendant.
  # - Stops at PID 1.
  #
  # We embed the helper in both install and run scripts to keep them self-contained.
  winAppInstall = ''
    # The executable has a date in the name, so we glob the end.
    wine ${src}/TakeControlViewerInstall-${version}* &
    installer_pid=$!

    is_descendant() {
      child=$1
      ancestor=$2

      # quick false for empty args
      if [ -z "$child" ] || [ -z "$ancestor" ]; then
        return 1
      fi

      # Walk up the parent chain
      while [ -n "$child" ] && [ "$child" != "1" ]; do
        if [ "$child" = "$ancestor" ]; then
          return 0
        fi

        if [ -r "/proc/$child/status" ]; then
          # PPid: <num>
          child=$(awk '/^PPid:/ {print $2}' /proc/$child/status 2>/dev/null)
        else
          # If we can't read the process info, assume it's not a descendant.
          return 1
        fi
      done

      # final check (in case ancestor == 1)
      [ "$child" = "$ancestor" ] && return 0 || return 1
    }

    # wait for the installer to emit the installcomplete window
    while ! pgrep -f "TakeControlRDViewer.exe -integrated -installcomplete" > /dev/null; do
      sleep 1
    done

    # Only terminate processes that are descendants of the installer we started.
    # This avoids killing other instances from other users or sessions.
    for p in $(pgrep -f "TakeControlRDViewer.exe" || true); do
      if is_descendant "$p" "$installer_pid"; then
        kill "$p" 2>/dev/null || true
      fi
    done

    for p in $(pgrep -f "TakeControlRDLdr.exe" || true); do
      if is_descendant "$p" "$installer_pid"; then
        kill "$p" 2>/dev/null || true
      fi
    done

    for p in $(pgrep -f "tkcuploader.exe" || true); do
      if is_descendant "$p" "$installer_pid"; then
        kill "$p" 2>/dev/null || true
      fi
    done
  '';

  winAppRun = ''
    wine "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Take Control Viewer/TakeControlRDLdr.exe" -- "$ARGS" &
    wine_pid=$!

    is_descendant() {
      child=$1
      ancestor=$2

      if [ -z "$child" ] || [ -z "$ancestor" ]; then
        return 1
      fi

      while [ -n "$child" ] && [ "$child" != "1" ]; do
        if [ "$child" = "$ancestor" ]; then
          return 0
        fi

        if [ -r "/proc/$child/status" ]; then
          child=$(awk '/^PPid:/ {print $2}' /proc/$child/status 2>/dev/null)
        else
          return 1
        fi
      done

      [ "$child" = "$ancestor" ] && return 0 || return 1
    }

    # Wait for any BASupClpHlp.exe processes that belong to our wine instance to finish.
    # If there are no BASupClpHlp.exe processes that are descendants of our wine process, proceed.
    while :; do
      found=
      for p in $(pgrep -f "BASupClpHlp.exe" || true); do
        if is_descendant "$p" "$wine_pid"; then
          found=1
          break
        fi
      done

      if [ -z "$found" ]; then
        break
      fi
      sleep 1
    done

    # When the helper is gone, only terminate processes that belong to this wine instance.
    for p in $(pgrep -f "TakeControlRDLdr.exe" || true); do
      if is_descendant "$p" "$wine_pid"; then
        kill "$p" 2>/dev/null || true
      fi
    done

    for p in $(pgrep -f "TakeControlRDViewer.exe" || true); do
      if is_descendant "$p" "$wine_pid"; then
        kill "$p" 2>/dev/null || true
      fi
    done

    for p in $(pgrep -f "tkcuploader.exe" || true); do
      if is_descendant "$p" "$wine_pid"; then
        kill "$p" 2>/dev/null || true
      fi
    done
  '';

  installPhase = ''
    runHook preInstall

    ln -s "$out/bin/.launcher" "$out/bin/${pname}"

    mkdir -p "$out/share/icons/hicolor/64x64/apps"
    icoextract ${src}/TakeControlViewerInstall-${version}* "/tmp/icon.ico"
    magick "/tmp/icon.ico[4]" "$out/share/icons/hicolor/64x64/apps/${pname}.png"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      exec = "${pname} %U";
      icon = pname;
      desktopName = "Take Control Viewer";

      mimeTypes = builtins.map (mt: "x-scheme-handler/${mt}") [
        "takectrsxvp"
        "tcarmmvp"
      ];
    })
  ];

  meta = with lib; {
    description = "Take Control Viewer for N-Sight";
    license = licenses.unfreeRedistributable;
    maintainers = with maintainers; [ racci ];
    platforms = platforms.linux;
    broken = stdenv.hostPlatform.isAarch64;
    mainProgram = pname;
  };
}
