{ stdenv
, lib
, zlib
, libgcc
, fetchurl
, autoPatchelfHook
}:

stdenv.mkDerivation rec {
  pname = "VrcAdvert";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/galister/VrcAdvert/releases/download/v${version}/VrcAdvert";
    hash = "sha256-9LxNV1hvhxfyPqgKb6jbKPYhAWAV/tq4TeUenJwWmfY=";
    executable = true;
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    zlib
    libgcc
    stdenv.cc.cc.lib
  ];

  dontUnpack = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -D $src $out/bin/VrcAdvert
    chmod a+x $out/bin/VrcAdvert
    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://github.com/galister/VrcAdvert";
    description = "Advertise your OSC app through OSCQuery.";
    platforms = platforms.linux;
    mainProgram = "VrcAdvert";
  };
}
