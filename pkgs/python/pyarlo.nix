{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
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

  meta = {
    description = "Asynchronous Arlo Component for Python";
    homepage = "https://github.com/twrecked/pyaarlo";
    changelog = "https://github.com/twrecked/pyaarlo/blob/${src.rev}/changelog";
    license = lib.licenses.unfree; # FIXME: nix-init did not find a license
    maintainers = with lib.maintainers; [ ];
  };
}
