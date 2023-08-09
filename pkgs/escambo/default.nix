{ pkgs ? import <nixpkgs> { inherit system; }
, lib ? pkgs.lib
, system ? builtins.currentSystem
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "escambo";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "CleoMenezesJr";
    repo = "escambo";
    rev = version;
    hash = "sha256-jMlix8nlCaVLZEhqzb6LRNrD3DUZMTIjqrRKo6nFbQA=";
  };

  nativeBuildInputs = with pkgs; [
    meson
    ninja
    gettext
    appstream-glib
    glib
    blueprint-compiler
    pkg-config
    python3
    # gtk3
    gtk4
    desktop-file-utils
  ];

  meta = with lib; {
    description = "Escambo is an HTTP-based APIs test application for GNOME";
    homepage = "https://github.com/CleoMenezesJr/escambo";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
  };
}
