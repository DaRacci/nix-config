{ stdenv
, lib
, fetchurl
, openssl
, libgcc
, autoPatchelfHook
}:

stdenv.mkDerivation rec {
  pname = "oscavmgr";
  version = "0.3.0-2";

  src = fetchurl {
    url = "https://github.com/galister/oscavmgr/releases/download/v${version}/oscavmgr-alvr";
    hash = "sha256-EJfp9ZGQH4+NhNXAln8DQC7QY2Lo5l4bjd7Ddes8rmI=";
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
