{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "jj-desc";
  version = "0.4.3";

  src = fetchFromGitHub {
    owner = "tumf";
    repo = "jj-desc";
    rev = "v${version}";
    hash = "sha256-ptenxz97I17xgfSzDKrF/ieOCe7u25i1bZz45nsPExw=";
  };

  cargoHash = "sha256-jhyxSU2FiLQ/uorCVRJxx5nElp7h9nTA4tOiH0msUIw=";

  meta = {
    description = "Generate jj (Jujutsu) commit descriptions automatically using LLMs";
    homepage = "https://github.com/tumf/jj-desc";
    license = lib.licenses.mit;
    mainProgram = "jj-desc";
    platforms = lib.platforms.all;
  };
}
