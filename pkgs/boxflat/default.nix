{ lib
, stdenv
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "boxflat";
  version = "1.8.0";

  src = fetchFromGitHub {
    owner = "Lawstorant";
    repo = "boxflat";
    rev = version;
    hash = "sha256-Xi9VGONokMONcihRR1DWh2x6XTxntJYpUIB33BfrKOs=";
  };

  meta = with lib; {
    description = "Boxflat for Moza Racing. Control your Moza gear settings";
    homepage = "https://github.com/Lawstorant/boxflat";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ Racci ];
    mainProgram = "boxflat";
    platforms = platforms.linux;
  };
}
