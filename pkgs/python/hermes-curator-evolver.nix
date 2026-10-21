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
    rev = "1aab2a9a7f80b0cd33ec4998e4067c6f355f6ffd";
    hash = "sha256-xwWxMIylbVFGj3jFqsMj4s0cwlf0fgfW+sKzhGNnGPc=";
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
