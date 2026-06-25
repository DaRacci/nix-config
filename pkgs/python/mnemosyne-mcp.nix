{
  lib,
  buildPythonPackage,
  fetchPypi,

  setuptools,

  mcp,
  anyio,
}:

buildPythonPackage rec {
  pname = "mnemosyne-mcp";
  version = "3.1.0";
  pyproject = true;

  src = fetchPypi {
    pname = "mnemosyne_memory";
    inherit version;
    hash = "sha256-Lem29U7XcXMAEc/FcJM3WtF+HDKwXG89Ze2LI7xy1bM=";
  };

  build-system = [ setuptools ];

  dependencies = [
    mcp
    anyio
  ];

  # Side-effect: init_db() runs at module import time, needs writable HOME
  preInstallCheck = ''
    export HOME=$(mktemp -d)
  '';

  pythonImportsCheck = [
    "mnemosyne"
    "mcp"
    "anyio"
  ];

  meta = {
    description = "MCP server variant of mnemosyne-memory — SQLite-backed memory provider with semantic recall for LLM agents";
    homepage = "https://pypi.org/project/mnemosyne-memory/";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.Racci ];
  };
}
