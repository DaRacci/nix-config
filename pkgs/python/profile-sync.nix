{
  lib,
  buildPythonApplication,
  hatchling,
  ruamel-yaml,
  pytestCheckHook,
}:
let
  pyproject = (builtins.fromTOML (builtins.readFile ./profile-sync/pyproject.toml)).project;
in
buildPythonApplication {
  pname = pyproject.name;
  version = pyproject.version;
  pyproject = true;

  src = ./profile-sync;

  build-system = [ hatchling ];

  dependencies = [ ruamel-yaml ];

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [ "profile_sync" ];

  meta = {
    description = "Reconcile Hermes profile config.yaml and .env against a nix-declared policy";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.racci ];
    mainProgram = "profile-sync";
  };
}
