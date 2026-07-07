{
  lib,

  buildPythonPackage,
  fetchFromGitHub,
  hatchling,
  pyyaml,

  nix-update-script,
}:

buildPythonPackage (attrs: {
  pname = "hermes-curator-evolver";
  version = "0.10.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "pingchesu";
    repo = "hermes-curator-evolver";
    rev = "main";
    hash = "sha256-Nh3YqB16/cA01U/TVcpx1Hx0yWgW/8h9iiIYZuVSxrc=";
  };

  build-system = [ hatchling ];

  dependencies = [ pyyaml ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Evidence-driven skill evolution for Hermes Agent";
    homepage = "https://github.com/pingchesu/hermes-curator-evolver";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.racci ];
    mainProgram = attrs.pname;
  };
})
