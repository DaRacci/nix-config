{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  nix-update-script,

  setuptools,
  wheel,

  click,
  cloudscraper,
  cryptography,
  paho-mqtt,
  pycryptodome,
  python-slugify,
  requests,
  unidecode,
}:

buildPythonPackage rec {
  pname = "pyaarlo";
  version = "0.8.0.15";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "twrecked";
    repo = "pyaarlo";
    rev = "v${version}";
    hash = "sha256-wWTIVADgAu3/egjyt+FgfutZsscWmc7SN7MTzhFBWso=";
  };

  build-system = [
    setuptools
    wheel
  ];

  dependencies = [
    click
    cloudscraper
    cryptography
    paho-mqtt
    pycryptodome
    python-slugify
    requests
    unidecode
  ];

  pythonImportsCheck = [
    "pyaarlo"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Asynchronous Arlo Component for Python";
    homepage = "https://github.com/twrecked/pyaarlo";
    changelog = "https://github.com/twrecked/pyaarlo/blob/${src.rev}/changelog";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ racci ];
  };
}
