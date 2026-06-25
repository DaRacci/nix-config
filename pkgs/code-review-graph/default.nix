{
  lib,
  fetchFromGitHub,
  nix-update-script,

  buildPythonApplication,
  hatchling,

  fastmcp,
  igraph,
  mcp,
  networkx,
  tree-sitter,
  tree-sitter-language-pack,
  watchdog,
}:

buildPythonApplication rec {
  pname = "code-review-graph";
  version = "2.3.6";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tirth8205";
    repo = "code-review-graph";
    rev = "v${version}";
    hash = "sha256-akuk4UHOTfw66dnuAeqoCkqF/JzsHqSzoTk5MQhEd0o=";
  };

  build-system = [ hatchling ];

  dependencies = [
    fastmcp
    igraph
    mcp
    networkx
    tree-sitter
    tree-sitter-language-pack
    watchdog
  ];

  # Wheel metadata has strict version bounds that don't match nixpkgs:
  # fastmcp 3.2.3 (requires >=3.2.4), tree-sitter-language-pack 1.4.1 (requires <1),
  # watchdog 6.0.0 (requires <6). All are API-compatible, so skip runtime dep check.
  dontCheckRuntimeDeps = true;

  pythonImportsCheck = [ "code_review_graph" ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Local-first knowledge graph for token-efficient code review through MCP and CLI";
    homepage = "https://code-review-graph.com";
    changelog = "https://github.com/tirth8205/code-review-graph/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "code-review-graph";
  };
}
