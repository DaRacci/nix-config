{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  fastembed,
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

  passthru.optional-dependencies = {
    embeddings = [ fastembed ];
    all = [ fastembed ];
  };

  pythonImportsCheck = [ "mnemosyne" ];

  passthru.withAll = buildPythonPackage {
    pname = "mnemosyne-memory-all";
    inherit version;
    pyproject = true;

    src = fetchPypi {
      pname = "mnemosyne_memory";
      inherit version;
      hash = "sha256-Lem29U7XcXMAEc/FcJM3WtF+HDKwXG89Ze2LI7xy1bM=";
    };

    build-system = [ setuptools ];

    propagatedBuildInputs = [ fastembed ];

    pythonImportsCheck = [ "mnemosyne" "fastembed" ];

    meta = {
      description = "mnemosyne-memory with all available optional features (embeddings via fastembed; ctransformers not in nixpkgs)";
      homepage = "https://pypi.org/project/mnemosyne-memory/";
      license = lib.licenses.mit;
      maintainers = [ lib.maintainers.racci ];
    };
  };

  meta = {
    description = "SQLite-backed memory provider with semantic recall for LLM agents";
    homepage = "https://pypi.org/project/mnemosyne-memory/";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.racci ];
  };
}
