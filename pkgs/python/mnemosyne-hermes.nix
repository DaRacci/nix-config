{
  lib,
  buildPythonPackage,
  fetchPypi,
  nix-update-script,

  setuptools,

  mnemosyne-memory,
  pyyaml,
}:

buildPythonPackage (attrs: {
  pname = "mnemosyne-hermes";
  version = "0.5.0";
  pyproject = true;

  src = fetchPypi {
    pname = "mnemosyne_hermes";
    inherit (attrs) version;
    hash = "sha256-CzEvnUw5oPFtT5bHQQ/GBdy2C/E7qShQn32irIRYKqw=";
  };

  build-system = [ setuptools ];

  dependencies = [
    mnemosyne-memory
    pyyaml
  ];

  pythonImportsCheck = [ "mnemosyne_hermes" ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Hermes Agent plugin wrapping Mnemosyne memory provider";
    homepage = "https://pypi.org/project/mnemosyne-hermes/";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.racci ];
    mainProgram = attrs.pname;
  };
})
