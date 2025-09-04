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
  version = "unstable-2025-09-01";

  src = fetchFromGitHub {
    owner = "daracci";
    repo = "proton-mcp";
    rev = "8ccabf467b530bd8ec485863a03682f2470f8433";
    hash = "sha256-Pn9gF1wUubvNjZmLn4/qucjNb5PTEOGcbYhPWSYFCJ0=";
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
