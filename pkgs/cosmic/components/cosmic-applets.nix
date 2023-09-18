{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, dbus
, glib
, libpulseaudio
, libxkbcommon
, vulkan-loader
, stdenv
, darwin
, wayland
}:

rustPlatform.buildRustPackage {
  pname = "cosmic-applets";
  version = "unstable-2023-08-08";

  src = fetchFromGitHub {
    owner = "pop-os";
    repo = "cosmic-applets";
    rev = "3ad64df5f31b30e11ee1fe368b02d5f65cad4fe2";
    hash = "sha256-UrCAFwUtPayYjd4rCrxijnCF589R4mmjNb8rlSTDlgI=";
  };

  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
    glib
    libpulseaudio
    libxkbcommon
    vulkan-loader
  ] ++ lib.optionals stdenv.isLinux [
    wayland
  ];

  meta = with lib; {
    description = "WIP applets for cosmic-panel";
    homepage = "https://github.com/pop-os/cosmic-applets";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
  };
}
