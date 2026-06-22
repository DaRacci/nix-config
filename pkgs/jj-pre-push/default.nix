{
  lib,
  buildPythonPackage,
  fetchFromGitHub,

  setuptools,

  typer,
}:
buildPythonPackage rec {
  pname = "jj-pre-push";
  version = "0.5.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "acarapetis";
    repo = "jj-pre-push";
    rev = "v${version}";
    hash = "sha256-AIsLUI42ewYqmgOP9livXE0tGAVWTfSh9K7h+PMObJg=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'requires = ["uv_build>=0.8.2,<0.11.0"]' 'requires = ["setuptools"]' \
      --replace-fail 'build-backend = "uv_build"' 'build-backend = "setuptools.build_meta"' \
      --replace-fail '"typer-slim>=0.19.0"' '"typer"'
  '';

  build-system = [
    setuptools
  ];

  dependencies = [
    typer
  ];

  pythonImportsCheck = [
    "jj_pre_push"
  ];

  meta = {
    description = "A pre-commit integration for jj";
    homepage = "https://github.com/acarapetis/jj-pre-push";
    license = lib.licenses.asl20;
    mainProgram = "jj-pre-push";
    platforms = lib.platforms.all;
  };
}
