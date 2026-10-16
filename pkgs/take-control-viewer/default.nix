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

    wine ${src}/TakeControlViewerInstall* &

    # Wait for the application stack.
    # Its appearance means the installer reached its final stage and has written all files.
    while ! pgrep -f "TakeControlRDLdr.exe" > /dev/null 2>&1; do
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
  '';

  winAppRun = ''
    # The app never exits on its own, all processes stay alive indefinitely after the remote session ends.
    # We launch wine in the background, detect the session lifecycle via BASupClpHlp.exe
    # (the clipboard/session helper that is present for exactly the duration of an active session),
    # and kill everything in the WINEPREFIX once the session ends.

    wine "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Take Control Viewer/TakeControlRDLdr.exe" -- "$ARGS" &

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

    # Kill all processes in this WINEPREFIX cleanly.
    wineserver -k
  '';

  installPhase = ''
    runHook preInstall

    ln -s "$out/bin/.launcher" "$out/bin/${pname}"

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

  meta = with lib; {
    description = "Take Control Viewer for N-Sight";
    license = licenses.unfreeRedistributable;
    maintainers = with maintainers; [ racci ];
    platforms = platforms.linux;
    broken = !stdenv.hostPlatform.isx86;
    mainProgram = pname;
  };
}
