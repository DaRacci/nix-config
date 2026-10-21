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
  version = "0.7.4";
  pyproject = true;

  src = fetchPypi {
    pname = "mnemosyne_hermes";
    inherit (attrs) version;
    hash = "sha256-92BfXleuTmayvI85oDN+O5FuOI1iPxxMZjMC4A3N860=";
  };

  #TODO:https://github.com/mnemosyne-oss/mnemosyne/pull/1125
  postPatch = ''
    substituteInPlace src/mnemosyne_hermes/__init__.py \
      --replace-fail "self._beam: Optional[Any] = None" ""
  '';

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
