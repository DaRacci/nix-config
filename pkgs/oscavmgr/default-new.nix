{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, autoAddDriverRunpath
, openssl
}:

rustPlatform.buildRustPackage rec {
  pname = "oscavmgr";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "galister";
    repo = "oscavmgr";
    rev = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-1cpisSevAU2zGNrpVEGvulBcWB5rWkWAIYI/0vjzRQE=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "alvr_common-20.10.0" = "sha256-2d5+9rxCpqgLMab7i1pLKaY1qSKRxzPI7pgh54rQBdg=";
      "openxr-0.19.0" = "sha256-kbEYoN4UvUEaZA9LJWEKx1X1r+l91GjTWs1hNXhr7cw=";
      "settings-schema-0.2.0" = "sha256-luEdAKDTq76dMeo5kA+QDTHpRMFUg3n0qvyQ7DkId0k=";
    };
  };

  nativeBuildInputs = [
    pkg-config

    rustPlatform.bindgenHook
    autoAddDriverRunpath
  ];

  buildInputs = [
    openssl
  ];

  meta = with lib; {
    description = " [Linux] Face tracking & utilities for Resonite and VRC";
    homepage = "https://github.com/galister/oscavmgr";
    maintainers = with maintainers; [ Racci ];
    platforms = platforms.linux;
    mainProgram = "oscavmgr";
  };
}
