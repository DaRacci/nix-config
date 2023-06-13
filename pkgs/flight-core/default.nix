{ lib
, stdenv
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "flight-core";
  version = "1.17.1";

  src = fetchFromGitHub {
    owner = "R2NorthstarTools";
    repo = "FlightCore";
    rev = "v${version}";
    hash = "sha256-oXu5jJ+MUo4kLyUWM9mnnE6qSh2/8GslgwrI4gLG8ms=";
  };

  meta = with lib; {
    description = "Installer/Updater/Launcher for Northstar";
    homepage = "https://github.com/R2NorthstarTools/FlightCore/";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
