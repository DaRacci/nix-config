{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, xz
, stdenv
, darwin
}:

rustPlatform.buildRustPackage rec {
  pname = "protonup-rs";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "auyer";
    repo = "Protonup-rs";
    rev = "v${version}";
    hash = "sha256-9szGLBs9yv1YPHqr7pAtfv7Vwb11uoe3k491ZaOrcqI=";
  };

  cargoSha256 = lib.fakeSha256;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    
  ] ++ lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
  ];

  meta = with lib; {
    description = "A Rust app to Install and Update GE-Proton for Steam, and Wine-GE for Lutris";
    homepage = "https://github.com/auyer/Protonup-rs";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
  };
}
