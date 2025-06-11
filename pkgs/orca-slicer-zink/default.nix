{
  lib,
  stdenv,
  makeWrapper,
  orca-slicer,
  mesa,
}:
stdenv.mkDerivation {
  pname = "orca-slicer-zink";
  inherit (orca-slicer) version;

  nativeBuildInputs = [ makeWrapper ];

  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/{bin,share/applications}

    cp ${lib.getExe orca-slicer} $out/bin/orca-slicer-zink
    cp -r ${orca-slicer}/share/icons $out/share
    cp ${orca-slicer}/share/applications/OrcaSlicer.desktop $out/share/applications/OrcaSlicer-zink.desktop

    wrapProgram $out/bin/orca-slicer-zink \
      --set GBM_BACKEND dri \
      --set __GLX_VENDOR_LIBRARY_NAME mesa \
      --set __EGL_VENDOR_LIBRARY_FILENAMES ${mesa}/share/glvnd/egl_vendor.d/50_mesa.json \
      --set MESA_LOADER_DRIVER_OVERRIDE zink \
      --set GALLIUM_DRIVER zink

    substituteInPlace $out/share/applications/OrcaSlicer-zink.desktop \
      --replace-fail 'Exec=orca-slicer' 'Exec=orca-slicer-zink'
  '';

  meta = lib.mergeAttrs orca-slicer.meta {
    description = "Orca-Slicer but with Zink overrides";
    mainProgram = "orca-slicer-zink";
  };
}
