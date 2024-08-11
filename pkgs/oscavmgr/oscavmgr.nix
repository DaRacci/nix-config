{ stdenv
, lib
, fetchurl
, openssl
, libgcc
, autoPatchelfHook
}:

stdenv.mkDerivation rec {
  pname = "oscavmgr";
  version = "0.3.3";

  src = fetchurl {
    url = "https://github.com/galister/oscavmgr/releases/download/v${version}/oscavmgr-alvr";
    hash = "sha256-fc8WuZAjZZHZG2/XmL07gUk2LaEX8B1LuwsHADjOJ5I=";
    executable = true;
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    openssl
    libgcc
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
  };
}
