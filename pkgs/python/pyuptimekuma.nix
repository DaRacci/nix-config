{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  nix-update-script,

  setuptools,
  wheel,

  aiodns,
  aiohttp,
  black,
  cchardet,
  isort,
  prometheus-client,
}:

buildPythonPackage rec {
  pname = "pyuptimekuma";
  version = "0.0.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jayakornk";
    repo = "pyuptimekuma";
    rev = "v${version}";
    hash = "sha256-JvgcL6ZkLJKpR3gRmv2WtrQrnT0beFSbyTfmsh2AZRE=";
  };

  build-system = [
    setuptools
    wheel
  ];

  dependencies = [
    aiodns
    aiohttp
    black
    cchardet
    isort
    prometheus-client
  ];

  pythonImportsCheck = [
    "pyuptimekuma"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Simple Python wrapper for Uptime Kuma";
    homepage = "https://github.com/jayakornk/pyuptimekuma";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ racci ];
  };
}
