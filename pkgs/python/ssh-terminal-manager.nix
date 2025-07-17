{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  icmplib,
  paramiko,
  terminal-manager,
  wakeonlan,
}:

buildPythonPackage rec {
  pname = "ssh-terminal-manager";
  version = "2.0.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "zhbjsh";
    repo = "ssh-terminal-manager";
    rev = "v${version}";
    hash = "sha256-TI34kutOwVJxadAxhnGJTmQbAru/PvAmVVlQRfYCa7I=";
  };

  build-system = [
    setuptools
  ];

  dependencies = [
    icmplib
    paramiko
    terminal-manager
    wakeonlan
  ];

  pythonImportsCheck = [
    "ssh_terminal_manager"
  ];

  meta = {
    description = "Control and monitor devices with SSH terminal commands";
    homepage = "https://github.com/zhbjsh/ssh-terminal-manager";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
