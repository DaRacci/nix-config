{
  lib,
  stdenv,
  fetchzip,
  fetchFromGitHub,

  autoPatchelfHook,
  nix-update-script,

  alsa-lib,
  brotli,
  ffmpeg,
  libdrm,
  gmp,
  libGL,
  libunwind,
  libva,
  libvdpau,
  libxkbcommon,
  openssl,
  pipewire,
  pulseaudio,
  vulkan-loader,
  wayland,
  x264,
  xorg,
  SDL2,
}:
stdenv.mkDerivation (finalAttrs: rec {
  pname = "alvr-bin";
  version = "20.12.1";

  src = fetchzip {
    url = "https://github.com/alvr-org/ALVR/releases/download/v${finalAttrs.version}/alvr_streamer_linux.tar.gz";
    hash = "sha256-u8LjXRWq+EnSSQvGPriTDvhN4agLbz2Pw2JIFPRStts=";
  };

  alvrSrc = fetchFromGitHub {
    owner = "alvr-org";
    repo = "ALVR";
    rev = "v${finalAttrs.version}";
    hash = "sha256-mvwwTME8GZYL+LkAVGX1d3DPSEDtaTEkuWo+vPNw4uw=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    alsa-lib
    libunwind
    libva
    libvdpau
    vulkan-loader
    pipewire
    SDL2
  ];

  runtimeDependencies = [
    brotli
    ffmpeg
    gmp
    libdrm
    libGL
    libxkbcommon
    openssl
    pipewire
    pulseaudio
    wayland
    x264
    xorg.libX11
    xorg.libXcursor
    xorg.libxcb
    xorg.libXi
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/applications
    cp -r $src/* $out
    install -Dm755 ${alvrSrc}/alvr/xtask/resources/alvr.desktop $out/share/applications/alvr.desktop
    install -Dm644 ${alvrSrc}/resources/ALVR-Icon.svg $out/share/icons/hicolor/scalable/apps/alvr.svg

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Stream VR games from your PC to your headset via Wi-Fi";
    homepage = "https://github.com/alvr-org/ALVR/";
    changelog = "https://github.com/alvr-org/ALVR/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ racci ];
    platforms = lib.platforms.linux;
    mainProgram = "alvr_dashboard";
  };
})
