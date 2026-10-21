{
  writeShellApplication,
  grimblast,
  libnotify,
  pulseaudio,
  satty,
  sound-theme-freedesktop,
  xdg-utils,
}:
writeShellApplication {
  name = "screenshot";
  runtimeInputs = [
    grimblast
    satty
    pulseaudio
    sound-theme-freedesktop
    libnotify
    xdg-utils
  ];
  text = ''
    export SCREENSHOT_SHUTTER_SOUND="${sound-theme-freedesktop}/share/sounds/freedesktop/stereo/camera-shutter.oga"

    ${builtins.readFile ./screenshot.sh}
  '';
}
