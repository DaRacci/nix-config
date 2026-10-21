{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  sqlite-vec,
  fastembed-hermes,
  mcp,
  anyio,
  cryptography,
  pyyaml,
}:

buildPythonPackage (attrs: {
  pname = "mnemosyne-memory";
  version = "4.0.0b4";
  pyproject = true;

  src = fetchPypi {
    pname = "mnemosyne_memory";
    inherit (attrs) version;
    hash = "sha256-+9PmpbHtaPStGiHTlxRlRX474ADB4EzrGVxJ+JcJBPQ=";
  };

  build-system = [ setuptools ];

  dependencies = [
    pyyaml
  ]
  ++ attrs.passthru.optional-dependencies.embeddings;

  passthru.optional-dependencies = {
    embeddings = [
      fastembed-hermes
      sqlite-vec
    ];
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
