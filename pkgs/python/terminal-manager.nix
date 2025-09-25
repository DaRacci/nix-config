{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  nix-update-script,

  setuptools,

  python-slugify,
}:

buildPythonPackage rec {
  pname = "terminal-manager";
  version = "2.0.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "zhbjsh";
    repo = "terminal-manager";
    rev = "v${version}";
    hash = "sha256-nc5SvzY/9efNNG4Y4p6BAgk8P6Ts+VaucBz0tz69y80=";
  };

  build-system = [
    setuptools
  ];

  dependencies = [
    python-slugify
  ];

  pythonImportsCheck = [
    "terminal_manager"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Control and monitor devices with terminal commands";
    homepage = "https://github.com/zhbjsh/terminal-manager";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ racci ];
  };
}
