{
  lib,
  stdenv,
  writeShellApplication,

  grimblast,
  imagemagick,
  libnotify,
  pulseaudio,
  sound-theme-freedesktop,
  tesseract,
  uutils-coreutils-noprefix,
  wl-clipboard,
}:
let
  inherit (lib) concatStringsSep;

  tessdata = stdenv.mkDerivation {
    name = "tessdata-multilang";
    buildCommand = ''
      mkdir $out
      ${concatStringsSep "\n" (
        map (lang: "cp ${lang} $out/${lang.name}") (
          with tesseract.passthru.languages;
          [
            eng
            jpn
            osd
          ]
        )
      )}
    '';
  };
in
writeShellApplication {
  name = "ocr-region";
  runtimeInputs = [
    uutils-coreutils-noprefix
    grimblast
    tesseract
    imagemagick
    wl-clipboard
    pulseaudio
    libnotify
  ];
  text = ''
    export OCR_REGION_SHUTTER_SOUND="${sound-theme-freedesktop}/share/sounds/freedesktop/stereo/camera-shutter.oga"
    export OCR_REGION_TESSDATA_PREFIX="${tessdata}"

    ${builtins.readFile ./ocr-region.sh}
  '';

  meta = {
    description = "A script to take a screenshot of a region and perform OCR on it";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
