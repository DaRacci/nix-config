{
  inputs,
  stdenvNoCC,
  wrapGAppsHook,
  gobject-introspection,
  ...
}:
let
  inherit (stdenvNoCC) system;
  ags = inputs.ags.packages.${system}.default;
  astalPkgs = inputs.astal.packages.${system};
in
stdenvNoCC.mkDerivation rec {
  name = "my-shell";
  src = ./src;

  nativeBuildInputs = [
    ags
    wrapGAppsHook
    gobject-introspection
  ];

  buildInputs = with astalPkgs; [
    astal4
    io
  ];

  installPhase = ''
    mkdir -p $out/bin
    ags bundle app.ts $out/bin/${name}
    chmod +x $out/bin/${name}
  '';
}
