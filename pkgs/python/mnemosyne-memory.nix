{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  fastembed,
  mcp,
  anyio,
  cryptography,
}:

buildPythonPackage (attrs: {
  pname = "mnemosyne-memory";
  version = "3.10.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mnemosyne-oss";
    repo = "mnemosyne";
    rev = "v${attrs.version}";
    hash = "sha256-hpNnKc8ZNbqcy9X4Yu/4zMGEW7TCyT9aEfRv03ffuig=";
  };

  build-system = [ setuptools ];

  passthru.optional-dependencies = {
    embeddings = [ fastembed ];
    sync = [ cryptography ];
    mcp = [
      mcp
      anyio
    ];
    all =
      with attrs.passthru;
      optional-dependencies.embeddings ++ optional-dependencies.mcp ++ optional-dependencies.sync;
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
})
