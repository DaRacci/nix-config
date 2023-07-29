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
    lollms_personal_path: /root/Documents/lollms
  '';
in
stdenv.mkDerivation rec {
  pname = "lollms-webui";
  version = "3.5";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "ParisNeo";
    repo = "lollms-webui";
    rev = "v${version}";
    hash = "sha256-BqcmRehAmW3XkJlsHQSNxcpZ2rQM783oB/nmJxMeDsw=";
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
