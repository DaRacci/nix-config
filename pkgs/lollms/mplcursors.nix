{ python3
, fetchFromGitHub
}: python3.pkgs.buildPythonPackage rec {
  pname = "mplcursors";
  version = "0.5.2 ";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "anntzer";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-ft/gDxbmGKRSxx/ftVQ+Q0szRLoUnuBH32fuIXVA/u4=";
  };

  propagatedBuildInputs = with python3.pkgs; [
    tqdm
    requests
    scikit-learn
    flask-socketio
    wget
    matplotlib
    pyyaml
    eventlet
  ];

  pythonImportsCheck = [ "mplcursors" ];
}
