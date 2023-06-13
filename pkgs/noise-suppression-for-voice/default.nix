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

  meta = with lib; {
    description = "Noise suppression plugin based on Xiph's RNNoise";
    homepage = "https://github.com/werman/noise-suppression-for-voice";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
  };
}
