{
  lib,
  fetchFromGitHub,
  nix-update-script,

  buildPythonApplication,
  hatchling,

  mcp,
  pyyaml,
  rich,

  portalocker,
  black,
  isort,
  mypy,
  pytest,
  pytest-cov,
  matplotlib,
  numpy,
  fastapi,
  pydantic,
  uvicorn,
}:

buildPythonApplication rec {
  pname = "mcp-sequential-thinking";
  version = "0.6.0-unstable-2026-07-03";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "arben-adm";
    repo = "mcp-sequential-thinking";
    rev = "8ec11b991487ba312d1f9b82b4b15d667b2e8b5e";
    hash = "sha256-8g8MKWNFNaeDPmo/ch17XUI9rRuXjh92ZmxRXqDWlxY=";
  };

  build-system = [
    hatchling
  ];

  dependencies = [
    mcp
    pyyaml
    rich
    portalocker
  ];

  optional-dependencies = {
    dev = [
      black
      isort
      mypy
      pytest
      pytest-cov
    ];
    vis = [
      matplotlib
      numpy
    ];
    web = [
      fastapi
      pydantic
      uvicorn
    ];
  };

  pythonImportsCheck = [
    "mcp_sequential_thinking"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "";
    homepage = "https://github.com/arben-adm/mcp-sequential-thinking";
    changelog = "https://github.com/arben-adm/mcp-sequential-thinking/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "mcp-sequential-thinking";
  };
}
