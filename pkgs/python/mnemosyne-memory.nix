{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  fastembed,
  mcp,
  anyio,
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
    mcp = [
      mcp
      anyio
    ];
    all = [
      fastembed
      mcp
      anyio
    ];
  };

  # init_db() runs at module import; wrapPythonPrograms triggers it
  preFixup = ''
    export HOME=$(mktemp -d)
  '';

  pythonImportsCheck = [ "mnemosyne" ];

  meta = {
    description = "SQLite-backed memory provider with semantic recall for LLM agents, with optional MCP server dependencies";
    homepage = "https://pypi.org/project/mnemosyne-memory/";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.racci ];
    mainProgram = "mnemosyne";
  };
}
