{ lib
, pkgs
, stdenv
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "dualsensectl";
  version = "0.4";

  src = fetchFromGitHub {
    owner = "nowrep";
    repo = "dualsensectl";
    rev = "v${version}";
    hash = "sha256-DrPVzbaLO2NgjNcEFyCs2W+dlbdpBeRX1ZfFenqz7IY=";
  };

  buildInputs = with pkgs; [
    pkg-config
    dbus
    hidapi
    udev
  ];

  meta = with lib; {
    description = "Linux tool for controlling PS5 DualSense controller";
    homepage = "https://github.com/nowrep/dualsensectl";
    license = licenses.gpl2Only;
    maintainers = with maintainers; [ ];
  };
}
