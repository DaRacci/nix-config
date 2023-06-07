{ lib
, stdenv
, fetchFromGitHub
, curl
, cmake
, pkg-config
, alsa-lib
, freetype
, webkitgtk
}:

stdenv.mkDerivation rec {
  pname = "noise-suppression-for-voice";
  version = "1.03";

  src = fetchFromGitHub {
    owner = "werman";
    repo = "noise-suppression-for-voice";
    rev = "v${version}";
    hash = "sha256-KAJLXnTiXjanmieeBlBHIUC2Mls2IjHfvDEp2OXSWak=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    pkg-config
    cmake
    curl
    alsa-lib
    freetype
    webkitgtk
  ];

  # libasound2-dev libjack-jackd2-dev \
  #   libcurl4-openssl-dev  \
  #   libfreetype6-dev \
  #   libx11-dev libxcomposite-dev libxcursor-dev libxcursor-dev libxext-dev libxinerama-dev libxrandr-dev libxrender-dev \
  #   libwebkit2gtk-4.0-dev

# - Checking for module 'alsa'
# --   No package 'alsa' found
# -- Checking for module 'freetype2'
# --   No package 'freetype2' found
# -- Checking for module 'libcurl'
# --   Found libcurl, version 8.0.1
# -- Checking for modules 'webkit2gtk-4.0;gtk+-x11-3.0'
# --   No package 'webkit2gtk-4.0' found
# --   No package 'gtk+-x11-3.0' found

  meta = with lib; {
    description = "Noise suppression plugin based on Xiph's RNNoise";
    homepage = "https://github.com/werman/noise-suppression-for-voice";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
  };
}
