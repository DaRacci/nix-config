{ pkgs, lib }:

pkgs.stdenv.mkDerivation rec {
  pname = "nix-software-center";
  version = "0.1.2";

  src = pkgs.fetchFromGithub {
    owner = "vlinkz";
    repo = "nix-software-center";
    version = "${version}";
    sha256 = "sha256-BFqCmkAnIxeVgzeMvTXFS/mgU1z1KOe74px03qnOvhM=";
  };

  meta = with lib; {
    description = "A software center for Nix based systems.";
    homepage = "https://github.com/vlinkz/nix-software-center";
    license = licenses.gpl3;
    maintainers = with maintainers; [ Racci ];
    platforms = platforms.linux;
  };
}