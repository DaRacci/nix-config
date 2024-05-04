{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "ficsit-cli";
  version = "0.5.1";

  src = fetchFromGitHub {
    owner = "satisfactorymodding";
    repo = "ficsit-cli";
    rev = "v${version}";
    hash = "sha256-gBwLXpXFGJTEwKvyrGBeW/HJmFXM8LXdvOeEg5FHh68=";
  };

  vendorHash = "sha256-Gf5VY5JzeLB33G8kh8WQs3mWdauaaI2jMCNZaVLydcM=";

  doCheck = false;

  ldflags = [ "-s" "-w" ];

  meta = with lib; {
    description = "A CLI tool for managing mods for the game Satisfactory";
    homepage = "https://github.com/satisfactorymodding/ficsit-cli";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
  };
}
