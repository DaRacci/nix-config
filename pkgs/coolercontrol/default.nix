{ lib
, rustPlatform
, fetchFromGitHub
# , python310Packages
# , poetry
# , liquidctl
# , buildPythonPackage
, stdenv
# , wheel
# , py
}:

let
  name = "coolercontrol";
  version = "0.16.0";

  coolercontrold = rustPlatform.buildRustPackage rec {
    pname = "${name}d";
    inherit version;

    src = fetchFromGitHub {
      owner = "codifryed";
      repo = name;
      rev = version;
      hash = "sha256-/O0VyN/yy4sDoUbkhEkOcFvSWdVcLeSlB0MZcfbJ5mg=";
    };

    sourceRoot = "source/${pname}";
    cargoHash = "sha256-fB8N8rBOsszTiSm78O2UMz8YnQ0/MboEs/JxY34ah/c=";

    doCheck = false;
  };

  # coolercontrol-gui = python311Packages.buildPythonPackage rec {
  #   pname = "${name}-gui";
  #   inherit version;
  #   # format = "wheel";

  #   src = coolercontrol-src;
  #   sourceRoot = "source/${pname}";

  #   doCheck = false;

  #   nativeBuildInputs = [
  #     python311Packages.build
  #     python311Packages.wheel
  #     python311Packages.installer
  #   ];

  #   runtimeDeps = [
  #     python311Packages.pyside6                                                                                                                                             
  #     python311Packages.matplotlib                                                                                                                                          
  #     python311Packages.numpy                                                                                                                                               
  #     python311Packages.setproctitle                                                                                                                                        
  #     python311Packages.jeepney                                                                                                                                             
  #     python311Packages.requests                                                                                                                                            
  #     python311Packages.fastapi                                                                                                                                             
  #     python311Packages.uvicorn                                                                                                                                             
  #     python311Packages.orjson                                                                                                                                              
  #     python311Packages.tomli
  #   ];
  # };

  # coolercontrol-liqctld = python311Packages.buildPythonPackage rec {
  #   pname = "${name}-liqctld";
  #   inherit version;
  #   format = "wheel";

  #   src = coolercontrol-src;
  #   sourceRoot = "source/${pname}";

  #   doCheck = false;

  #   nativeBuildInputs = [
  #     wheel
  #   ];

  #   propagatedBuildInputs = [
  #     py
  #     wheel
  #   ];

  #   runtimeDeps = [

  #   ];
  # };

in stdenv.mkDerivation { inherit name version coolercontrold; } // rec {
  pname = name;
  inherit version;

  src = fetchFromGitHub {
    owner = "codifryed";
    repo = name;
    rev = version;
    hash = "sha256-/O0VyN/yy4sDoUbkhEkOcFvSWdVcLeSlB0MZcfbJ5mg=";
  };

  dontBuild = true;

  # propagatedBuildInputs = [
  #   python310Packages.build
  #   python310Packages.wheel
  #   python310Packages.installer
  #   python310Packages.poetry-core
  #   poetry
  #   # fenix.minimal.toolchain
  # ];

  # runtimeDeps = [
  #   liquidctl
  #   python310Packages.pyside6                                                                                                                                             
  #   python310Packages.matplotlib                                                                                                                                          
  #   python310Packages.numpy                                                                                                                                               
  #   python310Packages.setproctitle                                                                                                                                        
  #   python310Packages.jeepney                                                                                                                                             
  #   python310Packages.requests                                                                                                                                            
  #   python310Packages.fastapi                                                                                                                                             
  #   python310Packages.uvicorn                                                                                                                                             
  #   python310Packages.orjson                                                                                                                                              
  #   python310Packages.tomli
  # ];

  # buildPhase = ''
  #   export HOME=$TEMPDIR

  #   cd ${src}/coolercontrol-gui
  #   python -m build --wheel --no-isolation --outdir /tmp/coolercontrol-gui
  #   cd ${src}/coolercontrol-liqctld
  #   python -m build --wheel --no-isolation --outdir /tmp/coolercontrol-liqctld
  # '';

  # installPhase = ''
  #   mkdir -p $out/bin

  #   install -Dm644 "packaging/systemd/${pname}d.service" -t "$out/lib/systemd/system/"
  #   install -Dm644 "packaging/systemd/${pname}-liqctld.service" -t "$out/lib/systemd/system/"
  # '';

  # installPhase = ''
  #   mkdir -p $out/bin
    
  #   cd ${src}/coolercontrol-gui
  #   python -m installer --destdir="$out/bin" dist/*.whl
  #   cd ${src}/coolercontrol-liqctld
  #   python -m installer --destdir="$out/bin" dist/*.whl
  #   cd ${src}/coolercontrold
  #   install -Dm755 target/release/coolercontrold -t "$out/bin"

  #   cd "${src}"
  #   install -Dm644 "packaging/systemd/${pname}d.service" -t "$out/usr/lib/systemd/system/"
  #   install -Dm644 "packaging/systemd/${pname}-liqctld.service" -t "$out/usr/lib/systemd/system/"

  #   install -Dm644 "packaging/metadata/${pname}.desktop" -t "$out/usr/share/applications/"
  #   install -Dm644 "packaging/metadata/${pname}.metainfo.xml" -t "$out/usr/share/metainfo/"
  #   install -Dm644 "packaging/metadata/${pname}.png" -t "$out/usr/share/pixmaps/"
  #   install -Dm644 "packaging/metadata/${pname}.svg" -t "$out/usr/share/icons/hicolor/scalable/apps/"
  # '';

  meta = with lib; {
    description = "A program to monitor and control your cooling devices";
    homepage = "https://github.com/codifryed/coolercontrol";
    changelog = "https://github.com/codifryed/coolercontrol/blob/${src.rev}/CHANGELOG.md";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ ];
  };
}
