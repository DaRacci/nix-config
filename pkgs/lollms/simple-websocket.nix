{ python3
, fetchPypi
}: python3.pkgs.buildPythonPackage rec {
  pname = "simple-websocket";
  version = "0.10.1";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-CrRsj/pRpG3JXu2UYIs7cihBwL+Ene9x1GXFw1ZnnII=";
  };

  doCheck = false;
  propagatedBuildInputs = with python3.pkgs; [
    wsproto
  ];
}
