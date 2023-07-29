{ lib
, pkgs
, python3
, fetchFromGitHub
}:
let
  simple-websocket = pkgs.callPackage ./simple-websocket.nix { };
in
python3.pkgs.buildPythonPackage {
  pname = "lollms";
  version = "unstable-2023-07-25";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "ParisNeo";
    repo = "lollms";
    rev = "5ff24a4db06f7a40855e4ec500653eaf656f06ae";
    hash = "sha256-17jztiRqiQWg9wSv87U8Oa109YswzO0bHtNzhzSWYBI=";
  };

  patches = [
    ./lollms-paths.patch
  ];

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
    wget
  ] ++ [ simple-websocket ];

  pythonImportsCheck = [ "lollms" ];

  meta = with lib; {
    description = "Lord of LLMS";
    homepage = "https://github.com/ParisNeo/lollms";
    license = licenses.asl20;
    maintainers = with maintainers; [ Racci ];
  };
}
