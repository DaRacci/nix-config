{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "ficsit-cli";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "satisfactorymodding";
    repo = "ficsit-cli";
    rev = "v${version}";
    hash = "sha256-zv1DYQUdcdRXjUVzBRHDVcTlxqOL36GApv4Okc4zLKM=";
  };

  vendorHash = "sha256-8hh75c7wArUIZ7wptLA6x+12T+Grw+Aa4l+lA0UG7IQ=";

  doCheck = false;

  ldflags = [ "-s" "-w" ];

  meta = with lib; {
    description = "A CLI tool for managing mods for the game Satisfactory";
    homepage = "https://github.com/satisfactorymodding/ficsit-cli";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
  };
}
