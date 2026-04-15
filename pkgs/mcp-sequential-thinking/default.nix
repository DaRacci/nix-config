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
  version = "0-unstable-2026-03-06";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "arben-adm";
    repo = "mcp-sequential-thinking";
    rev = "f3727d858769495befaf56e6b4f2e84509dc6456";
    hash = "sha256-ScKvb5Y9idY4TivY32dBlf1rb1M2i6oI0VfIcQ/6/SM=";
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
