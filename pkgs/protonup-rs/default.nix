{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
}:

rustPlatform.buildRustPackage rec {
  pname = "protonup-rs";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "auyer";
    repo = "Protonup-rs";
    rev = "v${version}";
    hash = "sha256-IE8QO9LaEllTYRRDA704SNWp4Ap2NQmoYMaKX4l9McY=";
  };

  doCheck = false; # Tests include external network gets. 

  cargoSha256 = "sha256-04EabrIlLwKPbrNIaJXi1WEDOdX3ojZrds5izzOymIg=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ ];

  meta = with lib; {
    description = "A Rust app to Install and Update GE-Proton for Steam, and Wine-GE for Lutris";
    homepage = "https://github.com/auyer/Protonup-rs";
    license = licenses.asl20;
    maintainers = with maintainers; [ Racci ];
  };
}
