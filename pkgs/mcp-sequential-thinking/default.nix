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
  version = "0-unstable-2026-06-13";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "arben-adm";
    repo = "mcp-sequential-thinking";
    rev = "2fad3ee8ab1d0868b6c1afb5895bc336a10e5267";
    hash = "sha256-kX5+KQCkk7wCf15+qusmDBjirbtJqOEROFqb6N8nvpw=";
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
