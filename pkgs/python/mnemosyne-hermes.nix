{
  lib,
  buildPythonPackage,
  fetchPypi,
  nix-update-script,

  setuptools,

  mnemosyne-memory,
}:

buildPythonPackage rec {
  pname = "mnemosyne-hermes";
  version = "3.1.0";
  pyproject = true;

  src = fetchPypi {
    pname = "mnemosyne_hermes";
    inherit version;
    hash = "sha256-639Y6MqRgUT0RDze3JKKuS1qe/nDifYOB7CExpGhh7k=";
  };

  build-system = [
    setuptools
  ];

  dependencies = [
    mnemosyne-memory
  ];

  pythonImportsCheck = [
    "mnemosyne_hermes"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Hermes Agent plugin wrapping Mnemosyne memory provider";
    homepage = "https://pypi.org/project/mnemosyne-hermes/";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.racci ];
  };
}
