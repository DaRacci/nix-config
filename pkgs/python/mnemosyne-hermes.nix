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
  version = "0.3.1";
  pyproject = true;

  src = fetchPypi {
    pname = "mnemosyne_hermes";
    inherit version;
    hash = "sha256-XxCgqRxIm/ylBx93/zH9k8/c0ZiXq4qTM4xZXxQBFIc=";
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
