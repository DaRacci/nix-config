{
  pkgs,
  lib,
  stdenv,
  fetchFromGitHub,
  installShellFiles,
  makeBinaryWrapper,
}:
let
  runtimeDeps = with pkgs; [
    fish
    ddcutil
    brightnessctl
    app2unit
    cava
    networkmanager
    lm_sensors
    aubio
    pipewire
    grim
    swappy
    libqalculate
    quickshell
    inotify-tools
    bluez
    bash
    busybox
  ];
in
stdenv.mkDerivation {
  pname = "caelestia-shell";
  version = "unstable-2025-07-08";

  src = fetchFromGitHub {
    owner = "caelestia-dots";
    repo = "shell";
    rev = "18b6a321deb83a28ce1d86395e6de8603fb46375";
    hash = "sha256-jDCwHEQiscDTrrj/Oh9Hck6Vvum62lrCNpfsV/GDtEA=";
  };

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
  ];

  buildInputs = [
    pkgs.fish
  ];

  propogatedBuildInputs = runtimeDeps;

  installPhase = ''
    mkdir -p $out/{bin,share/caelestia-shell}

    cp run.fish $out/bin/shell
    cp -R * $out/share/caelestia-shell
  '';

  patchPhase = ''
    substituteInPlace shell.qml \
      --replace-fail "//@ pragma Env QS_NO_RELOAD_POPUP=1" "
      //@ pragma Env QS_NO_RELOAD_POPUP=1
      //@ pragma UseQApplication
      "

    substituteInPlace run.fish \
      --replace-fail "(dirname (status filename))" "$out/share/caelestia-shell"
  '';

  postFixup = ''
    wrapProgram $out/bin/shell \
      --set PATH ${lib.makeBinPath runtimeDeps} \
      --suffix XDG_DATA_DIRS : "$out/share/caelestia-shell:${pkgs.material-symbols}/share"
  '';

  meta = {
    description = "A very segsy desktop shell";
    homepage = "https://github.com/caelestia-dots/shell";
    license = lib.licenses.gpl3Only;
    mainProgram = "shell";
    platforms = lib.platforms.all;
  };
}
