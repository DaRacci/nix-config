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
  faust-cchardet,
  isort,
  prometheus-client,
}:

buildPythonPackage rec {
  pname = "pyuptimekuma";
  version = "0.0.6";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jayakornk";
    repo = "pyuptimekuma";
    rev = "v${version}";
    hash = "sha256-DUr3UGNfHIbY0psuSBUV2o70VNkLwAdTG93SINwulpU=";
  };

  build-system = [
    setuptools
    wheel
  ];

  dependencies = [
    aiodns
    aiohttp
    black
    faust-cchardet
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
