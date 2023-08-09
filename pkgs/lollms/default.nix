{ lib
, pkgs
, python3
, fetchFromGitHub
}:
python3.pkgs.buildPythonPackage {
  pname = "lollms";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "ParisNeo";
    repo = "lollms";
    rev = "d21ba70dff809429a504ae374da1b57356e29080";
    hash = "sha256-ft/gDxbmGKRSxx/ftVQ+Q0szRLoUnuBH32fuIXVA/u4=";
  };

  # patches = [
  #   ./lollms-paths.patch
  # ];

  propagatedBuildInputs = with python3.pkgs; [
    eventlet
    flask
    flask-cors
    flask-socketio
    pillow
    pyyaml
    pydantic
    langchain
    requests
    setuptools
    tqdm
  ] ++ (with pkgs; [ simple-websocket ]);

  pythonImportsCheck = [ "lollms" ];

  meta = with lib; {
    description = "Lord of LLMS";
    homepage = "https://github.com/ParisNeo/lollms";
    license = licenses.asl20;
    maintainers = with maintainers; [ Racci ];
  };
}
