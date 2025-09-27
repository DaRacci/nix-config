{
  lib,
  fetchFromGitHub,
  buildPythonApplication,
  python,
  setuptools,
  nix-update-script,
}:
buildPythonApplication rec {
  pname = "proton-mcp";
  version = "0-unstable-2025-09-01";

  src = fetchFromGitHub {
    owner = "daracci";
    repo = "proton-mcp";
    rev = "85bd355bd082e786af7abf81952aa47d278a293f";
    hash = "sha256-qNXEzpMYpXAerlgh2ctigIsGJORswRyAgNR+Gh7HQj0=";
  };

  pyproject = true;
  doCheck = false;

  nativeBuildInputs = [ setuptools ];
  propagatedBuildInputs = with python.pkgs; [
    requests
    python-dotenv
    mcp
  ];

  preBuild = ''
    mkdir protonmail_mcp
    cp ${src}/proton-email-server.py protonmail_mcp/entrypoint.py
    substituteInPlace protonmail_mcp/entrypoint.py \
      --replace-fail 'if __name__ == "__main__":' 'def main():'

    cat > setup.py << EOF
    from setuptools import setup
    from importlib_metadata import entry_points

    with open('requirements.txt') as f:
      requirements = f.read().splitlines()

    setup(
      name='proton_mcp',
      packages=['protonmail_mcp'],
      install_requires=requirements,
      entry_points={
        'console_scripts': [
          'proton-mcp = protonmail_mcp.entrypoint:main',
        ],
      },
    )
    EOF

    ls -la
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "";
    homepage = "https://github.com/ccunning2/proton-mcp";
    license = lib.licenses.unfree; # FIXME: nix-init did not find a license
    maintainers = with lib.maintainers; [ racci ];
    mainProgram = "proton-mcp";
    platforms = lib.platforms.all;
  };
}
