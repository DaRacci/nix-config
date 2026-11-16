{
  stdenv,
  lib,
  pkgs,

  mkWindowsAppNoCC,
  fetchzip,

  makeDesktopItem,
  copyDesktopItems,

  wine,
  icoextract,
  imagemagick,
  libnotify,
  writeShellScriptBin,

  xdotool,
  xprop,
}:
let
  inherit (lib) licenses maintainers platforms;
  inherit (maintainers) racci;

  # mkWindowsApp reuses a fixed bottle under /tmp.
  # A killed launcher or a deleted layer leaves a dead unionfs mount there,
  # after which Wine sees an unreadable prefix and exits on every launch.
  # Also clear the install lock left behind by an interrupted install.
  wrapper = writeShellScriptBin "take-control-viewer" ''
    _launcher=@LAUNCHER@
    _recovered=

    if command -v findmnt > /dev/null 2>&1 && command -v pgrep > /dev/null 2>&1; then
      for _mnt in $(findmnt -rn -o TARGET -t fuse.unionfs 2> /dev/null); do
        case "$_mnt" in
          /tmp/*.mkwindowsapp/wineprefix) ;;
          *) continue ;;
        esac

        if ! pgrep -f -- "unionfs .*$_mnt" > /dev/null 2>&1; then
          if command -v fusermount3 > /dev/null 2>&1 && fusermount3 -uz "$_mnt" 2> /dev/null; then
            _recovered=1
          fi
        fi
      done
    fi

    # The launcher only removes its lock after a successful install.
    # A leftover lock makes every later launch refuse to start.
    if [ -n "$USER" ] && command -v sha256sum > /dev/null 2>&1 && command -v pgrep > /dev/null 2>&1; then
      _run_hash=$(sed -n 's/^RUN_LAYER_HASH=//p' "$_launcher" 2> /dev/null)
      if [ -n "$_run_hash" ]; then
        _lock="/tmp/$(printf '%s %s' "$_run_hash" "$USER" | sha256sum | cut -d' ' -f1).lock"
        if [ -d "$_lock" ] && ! pgrep -f -- 'bin/[.]launcher' > /dev/null 2>&1; then
          if rmdir "$_lock" 2> /dev/null; then
            _recovered=1
          fi
        fi
      fi
    fi

    if [ -n "$_recovered" ]; then
      ${libnotify}/bin/notify-send -i dialog-information "Take Control Viewer" "Recovered from an interrupted session." 2> /dev/null || true
    fi

    # Desktop launches have no terminal; keep the launcher output for diagnosis.
    if [ ! -t 1 ] && [ -n "$HOME" ]; then
      _state="''${XDG_STATE_HOME:-$HOME/.local/state}/take-control-viewer"
      mkdir -p "$_state"
      [ -f "$_state/launcher.log" ] && mv -f "$_state/launcher.log" "$_state/launcher.log.1"
      exec "$_launcher" "$@" >> "$_state/launcher.log" 2>&1
    fi

    exec "$_launcher" "$@"
  '';
in
mkWindowsAppNoCC rec {
  inherit wine;

  pname = "take-control-viewer";
  version = "7.44.08";

  src = fetchzip {
    url = "https://swi-rc.cdn-sw.net/logicnow/linux_viewer/${version}/LinuxNSight.zip";
    hash = "sha256-5lM6q/7fKyW6ouMpeH2ov7fzJR75Hbg9TzxaiqIox0w=";
  };

  enableMonoBootPrompt = false;

  nativeBuildInputs = [
    copyDesktopItems

    icoextract
    imagemagick
  ];

  # xdotool + xprop are added to the launcher PATH; winAppRun uses them to hide the viewer's placeholder window.
  buildInputs = [
    xdotool
    xprop
  ];

  wineArch = "win64";
  fileMap = {
    "$HOME/.local/share/take-control-viewer" = "drive_c/users/$USER/AppData/Local/Take Control Viewer";
  };

  graphicsDriver = "auto";
  enableVulkan = false;

  winAppInstall = ''
    # The installer writes every file, then launches the application stack from its "run after install" step, and only then exits.
    # Those processes never exit on their own.
    # All Wine-managed processes are re-parented to the session leader, so PID ancestry tracking is useless here.
    # Instead, we watch the installer process and then use wineserver -k, which is scoped to $WINEPREFIX and safely kills only processes belonging to this prefix.

    # Wine 11 ships Mono 10, and loading it crashes this native installer with a heap corruption error before it writes anything.
    # Disable Mono and Gecko for the installer process; the viewer brings its own runtime.
    export WINEDLLOVERRIDES="mscoree=d;mshtml=d;$WINEDLLOVERRIDES"

    _install_failed () {
      echo "take-control-viewer: $1" >&2
      notify-send -i dialog-error "Take Control Viewer" "$1" 2> /dev/null || true
      wineserver -k 2> /dev/null || true
      # The launcher removes this lock only after a successful install.
      rmdir "$LOCKFILE" 2> /dev/null || true
      # mkWindowsApp ignores this callback's status, so stop the launcher before
      # it marks the empty app layer as complete.
      kill -TERM "$PPID"
      exit 1
    }

    wine ${src}/TakeControlViewerInstall* &
    _installer_pid=$!

    # Wait for the application stack.
    # Its appearance means the installer reached its final stage and has written all files.
    while ! pgrep -f "TakeControlRDLdr.exe" > /dev/null 2>&1; do
      # A vanished installer before the application stack means the install failed.
      if ! kill -0 "$_installer_pid" 2> /dev/null; then
        _install_failed "Installer exited before writing TakeControlRDLdr.exe."
      fi
      sleep 1
    done

    # Wait for the installer to exit.
    # The installer process exiting is the completion signal.
    while pgrep -f "TakeControlViewerInstall" > /dev/null 2>&1; do
      sleep 1
    done

    # Installation confirmed. Kill all processes in this WINEPREFIX so the
    # subsequent wineserver -w in mkWindowsApp returns promptly.
    wineserver -k

    if [ ! -f "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Take Control Viewer/TakeControlRDLdr.exe" ]; then
      _install_failed "Installer did not write TakeControlRDLdr.exe."
    fi
  '';

  winAppRun = ''
    # The app never exits on its own, all processes stay alive indefinitely after the remote session ends.
    # We launch wine in the background, detect the session lifecycle via BASupClpHlp.exe
    # (the clipboard/session helper that is present for exactly the duration of an active session),
    # and kill everything in the WINEPREFIX once the session ends.

    # A previously poisoned app layer would otherwise fail inside Wine with no clue.
    _viewer="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Take Control Viewer/TakeControlRDLdr.exe"
    if [ ! -f "$_viewer" ]; then
      echo "take-control-viewer: $_viewer is missing; the app layer is incomplete." >&2
      notify-send -i dialog-error "Take Control Viewer" "Installation is incomplete. Retry with: WA_CLEAN_APP=1 take-control-viewer" 2> /dev/null || true
      wineserver -k 2> /dev/null || true
      return 1
    fi

    wine "$_viewer" -- "$ARGS" &

    # When a session starts the viewer also opens an empty, fixed-size placeholder window and never hides it under Wine, leaving a blank white box.
    # Unmap any such window while the app runs.
    _unmap_placeholder_windows () {
      while :; do
        for _win in $(xdotool search --onlyvisible --class takecontrolrdviewer.exe 2> /dev/null); do
          _hex=$(printf '0x%x' "$_win")
          if xprop -id "$_hex" WM_HINTS 2> /dev/null | grep -q "group leader: $_hex$"; then
            xdotool windowunmap "$_win" 2> /dev/null
          fi
        done
        sleep 2
      done
    }

    if [ -n "$DISPLAY" ] && command -v xdotool > /dev/null 2>&1; then
      _unmap_placeholder_windows &
      _placeholder_watcher=$!
    fi

    # Wait for BASupClpHlp.exe to appear, confirming the session is active.
    # Timeout after 5 minutes in case the connection is never established.
    _timeout=300
    while ! pgrep -x "BASupClpHlp.exe" > /dev/null 2>&1; do
      sleep 1
      _timeout=$((_timeout - 1))
      if [ "$_timeout" -le 0 ]; then
        break
      fi
    done

    # Wait for BASupClpHlp.exe to exit, which signals the remote session has ended.
    # All other processes remain alive forever without this explicit kill.
    while pgrep -x "BASupClpHlp.exe" > /dev/null 2>&1; do
      sleep 1
    done

    # Stop the placeholder watcher.
    if [ -n "$_placeholder_watcher" ]; then
      kill "$_placeholder_watcher" 2> /dev/null
    fi

    # Kill all processes in this WINEPREFIX cleanly.
    wineserver -k
  '';

  installPhase = ''
    runHook preInstall

    cp ${wrapper}/bin/take-control-viewer "$out/bin/${pname}"
    substituteInPlace "$out/bin/${pname}" --replace-fail "@LAUNCHER@" "$out/bin/.launcher"

    mkdir -p "$out/share/icons/hicolor/64x64/apps"
    icoextract ${src}/TakeControlViewerInstall* "/tmp/icon.ico"
    magick "/tmp/icon.ico[4]" "$out/share/icons/hicolor/64x64/apps/${pname}.png"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      exec = "${pname} %U";
      icon = pname;
      desktopName = "Take Control Viewer";

      mimeTypes = map (mt: "x-scheme-handler/${mt}") [
        "takectrsxvp"
        "tcarmmvp"
      ];
    })
  ];

  meta = {
    description = "Take Control Viewer for N-Sight";
    license = licenses.unfreeRedistributable;
    maintainers = [ racci ];
    platforms = platforms.linux;
    broken = !stdenv.hostPlatform.isx86;
    mainProgram = pname;
  };

  passthru.tests.install-and-launch = import ./tests/install-and-launch.nix {
    inherit pkgs;
    take-control-viewer = pkgs.take-control-viewer;
  };
}
