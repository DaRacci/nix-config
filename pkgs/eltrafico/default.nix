{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, atk
, cairo
, gdk-pixbuf
, glib
, gtk3
, pango
}:

rustPlatform.buildRustPackage rec {
  pname = "eltrafico";
  version = "2.3.6";

  src = fetchFromGitHub {
    owner = "sigmaSd";
    repo = "Eltrafico";
    rev = version;
    hash = "sha256-8/ba15fRRGs2yucXbaAKTaBIiDHRg13nEUG7MSkvtyk=";
  };

  cargoHash = "sha256-LmHG3MbrZGLVnD6m9SLzBvMTLjOSucUuXKbApZwn5Uo=";

  nativeBuildInputs = [
    pkg-config
  ];

  doCheck = false;

  buildInputs = [
    atk
    cairo
    gdk-pixbuf
    glib
    gtk3
    pango
  ];

  meta = with lib; {
    description = "NetLimiter-like traffic shaping for Linux";
    homepage = "https://github.com/sigmaSd/Eltrafico";
    changelog = "https://github.com/sigmaSd/Eltrafico/blob/${src.rev}/CHANGELOG.md";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
  };
}
