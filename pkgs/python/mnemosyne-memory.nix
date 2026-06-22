{
  lib,
  buildPythonPackage,
  fetchPypi,

  setuptools,
}:

buildPythonPackage rec {
  pname = "mnemosyne-memory";
  version = "3.1.0";
  pyproject = true;

  src = fetchPypi {
    pname = "mnemosyne_memory";
    inherit version;
    hash = "sha256-Lem29U7XcXMAEc/FcJM3WtF+HDKwXG89Ze2LI7xy1bM=";
  };

  build-system = [ setuptools ];

  pythonImportsCheck = [ "mnemosyne" ];

  meta = {
    description = "SQLite-backed memory provider with semantic recall for LLM agents";
    homepage = "https://pypi.org/project/mnemosyne-memory/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
