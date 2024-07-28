{ pkgs
, lib
, stdenv
, fetchFromGitHub
, kernel ? pkgs.kernel
}:

stdenv.mkDerivation rec {
  pname = "universal-pidff-${version}-${kernel.version}";
  version = "0.0.5";

  src = fetchFromGitHub {
    owner = "JacKeTUs";
    repo = "universal-pidff";
    rev = version;
    hash = "sha256-W30AoC42Laq/OpsGy2tflrQkwlM0TKQMDtyhUl7xF3s=";
  };

  hardeningDisable = [ "pic" "format" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KVER=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=$(out)"
  ];

  installPhase = ''
    install -D hid-universal-pidff.ko -t "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/hid"
  '';

  meta = with lib; {
    description = "Linux PIDFF driver with useful patches for initialization of FFB devices. Primarily targeting Direct Drive wheelbases.";
    homepage = "https://github.com/JacKeTUs/universal-pidff";
    license = licenses.gpl2Only;
    maintainers = with maintainers; [ Racci ];
    mainProgram = "universal-pidff";
    platforms = platforms.linux;
  };
}
