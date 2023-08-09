{ pkgs
, lib
, python3
, stdenv
, fetchFromGitHub
, makeWrapper
}:
let
  pythonEnv = python3.withPackages (ps: with ps; [
    eventlet
    flask
    flask-socketio
    gevent
    gevent-websocket
    gitpython
    langchain
    markdown
    numpy
    psutil
    pytest
    pyyaml
    requests
    setuptools
    tqdm
    websocket-client
  ] ++ [ pkgs.lollms ]);

  configFile = pkgs.writeText "global_paths_cfg.yaml" ''
    lollms_path: ${pkgs.lollms}/lib/python3.10/site-packages/lollms
    # lollms_personal_path: /root/Documents/lollms
  '';
in
stdenv.mkDerivation {
  pname = "lollms-webui";
  version = "unstable-2023-08-01";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "ParisNeo";
    repo = "lollms-webui";
    rev = "c68138042cb84a0f2f43f0dec5a690631603c2eb";
    hash = "sha256-fpj+RQc50P9YnwKXz5vM48wDI1fnv4Eb4tD7PLCSjbQ=";
  };

  nativeBuildInputs = [ makeWrapper ];

  configurePhase = "#do nothing";
  buildPhase = "#do nothing";

  installPhase = ''
    dir=$out/opt/lollms
    mkdir -p $dir

    cp -r ./app.py $dir
    cp -r ./api $dir
    cp -r ./static $dir
    cp -r ./templates $dir
    cp -r ./web $dir
    cp -r ./configs $dir
    cp -r ./assets $dir
    cp -r ${configFile} $dir/global_paths_cfg.yaml

    mkdir -p $out/bin
    makeWrapper ${pythonEnv}/bin/python $out/bin/lollms-webui \
      --add-flags "$dir/app.py" \
      --set PYTHONPATH "${pythonEnv}/${pythonEnv.sitePackages}:$PYTHONPATH"
  '';

  meta = with lib; {
    description = "Gpt4all chatbot ui";
    homepage = "https://github.com/ParisNeo/lollms-webui";
    license = licenses.asl20;
    maintainers = with maintainers; [ Racci ];
  };
}
