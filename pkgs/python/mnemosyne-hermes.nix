{
  lib,
  buildPythonPackage,
  fetchPypi,
  nix-update-script,

  setuptools,

  mnemosyne-memory,
}:

buildPythonPackage (attrs: {
  pname = "mnemosyne-hermes";
  version = "0.4.0";
  pyproject = true;

  src = fetchPypi {
    pname = "mnemosyne_hermes";
    inherit (attrs) version;
    hash = "sha256-fkh+cNVXIJXOQDxf8ZQxQSBgp+9WyH/ERW2kmbBHTrg=";
  };

  build-system = [ setuptools ];

  dependencies = [ mnemosyne-memory ];

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
