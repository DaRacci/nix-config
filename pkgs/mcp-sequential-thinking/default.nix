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
  version = "0-unstable-2025-07-15";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "arben-adm";
    repo = "mcp-sequential-thinking";
    rev = "f8259ce852cffc97783a1737d7e1985ce385f440";
    hash = "sha256-tAIUGHmdmowmyD4tw2WI8wRdE582NLGFmHEfgPXKxxs=";
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
