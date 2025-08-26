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

  # enableMonoBootPrompt = true;
  # persistRegistry = true;
  # persistRuntimeLayer = true;
  enableInstallNotification = false;
  # inhibitIdle = true;
  graphicsDriver = "wayland";
  # enableVulkan = true;

  winAppInstall = ''
    # The executable has a date in the name, so we glob the end.
    wine ${src}/TakeControlViewerInstall-${version}*
  '';

  winAppRun = ''
    wine "$WINEPREFIX/drive_c/users/$USER/AppData/Local/Take Control Viewer/TakeControlRDLdr.exe" "$ARGS"
  '';

  installPhase = ''
    runHook preInstall

    ln -s "$out/bin/.launcher" "$out/bin/${pname}"

    mkdir -p "$out/share/icons/hicolor/256x256/apps"
    icoextract ${src}/TakeControlViewerInstall-${version}* "/tmp/icon.ico"
    magick "/tmp/icon.ico" "$out/share/icons/hicolor/256x256/apps/${pname}.png"

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
