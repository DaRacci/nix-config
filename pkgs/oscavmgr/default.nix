{ stdenv
, lib
, fetchurl
, openssl
, openxr-loader
, libgcc
, autoPatchelfHook
}:

stdenv.mkDerivation rec {
  pname = "oscavmgr";
  version = "0.4.1";

  src = fetchurl {
    url = "https://github.com/galister/oscavmgr/releases/download/v${version}/oscavmgr";
    hash = "sha256-m8A1Mo4MRrxYUMTn+w2YFH366n2HwOinqtDp3q9K6wQ=";
    executable = true;
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    openssl
    libgcc
    openxr-loader
  ];

  dontUnpack = true;

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -m755 -D $src $out/bin/oscavmgr
    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://github.com/galister/oscavmgr";
    description = " [Linux] Face tracking & utilities for Resonite and VRC";
    platforms = platforms.linux;
    mainProgram = "oscavmgr";
  };
}
