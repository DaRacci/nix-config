{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  libusb1,
  hidapi,
  libserialport,
  libxml2,
  argtable,
  libconfig,
  libpulseaudio,
  portaudio,
  jansson,
  libuv,
  libxdg_basedir,
}:

stdenv.mkDerivation rec {
  pname = "monocoque";
  version = "d054f03";

  src = fetchFromGitHub {
    owner = "Spacefreak18";
    repo = "monocoque";
    rev = version;
    hash = "sha256-ebBLgrFzrWFvM25vrzYT8LpSvDLoSd+bWlaxXefWyg8=";
    fetchSubmodules = true;
  };

  postPatch = ''
    substituteInPlace src/monocoque/helper/parameters.c \
      --replace-warn 'argtable2.h' 'argtable3.h'

    substituteInPlace $(find . -name CMakeLists.txt) \
      --replace-warn 'argtable2' 'argtable3' \
      --replace-warn 'LIBUSB_INCLUDE_DIR /usr/include' 'LIBUSB_INCLUDE_DIR ${lib.getDev libusb1}/include' \
      --replace-warn 'LIBXML_INCLUDE_DIR /usr/include' 'LIBXML_INCLUDE_DIR ${lib.getDev libxml2}/include'
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib/udev}
    install -m755 -D monocoque $out/bin/monocoque

    cp -r $src/udev $out/lib/udev
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    libusb1
    hidapi
    libserialport
    libxml2
    argtable
    libconfig
    libpulseaudio
    portaudio
    jansson
    libuv
    libxdg_basedir
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=RELEASE"
    "-DCMAKE_INSTALL_PREFIX=$(out)"
    "-DUSE_PULSEAUDIO=yes"
    "-Wno-dev"
  ];

  meta = {
    description = "A device manager for driving and flight simulators, for use with common simulator software titles";
    homepage = "https://github.com/Spacefreak18/monocoque";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "monocoque";
    platforms = lib.platforms.all;
  };
}
