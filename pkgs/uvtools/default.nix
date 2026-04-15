{
  appimageTools,
  fetchurl,
}:
let
  pname = "UVtools";
  version = "6.0.3";

  src = fetchurl {
    url = "https://github.com/sn4k3/${pname}/releases/download/v${version}/${pname}_linux-x64_v${version}.AppImage";
    hash = "sha256-aKhI1zV2mQIf2ZVJ5MSlsLotn8g7VHdmIPV3dSBRtKo=";
  };

in
appimageTools.wrapType2 {
  inherit pname version src;
  extraPkgs = pkgs: [
    pkgs.icu
    pkgs.alsa-utils
    pkgs.toybox
  ];
}
