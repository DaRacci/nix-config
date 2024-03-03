{ lib
, buildGoModule
, fetchFromGitHub
, makeBinaryWrapper
, pkg-config
, libGL
, libxkbcommon
, xorg
, wayland
, vulkan-headers
, samba
, fetchpatch
, pkgs
}:
let
  wine = pkgs.unstable.wine64Packages.staging.overrideDerivation (oldAttrs: {
    patches =
      (oldAttrs.patches or [ ])
      ++ [
        (fetchpatch {
          name = "vinegar-wine-segregrevert.patch";
          url = "https://raw.githubusercontent.com/flathub/org.vinegarhq.Vinegar/e24cb9dfa996bcfeaa46504c0375660fe271148d/patches/wine/segregrevert.patch";
          hash = "sha256-+3Nld81nG3GufI4jAF6yrWfkJmsSCOku39rx0Hov29c=";
        })
        (fetchpatch {
          name = "vinegar-wine-mouselock.patch";
          url = "https://raw.githubusercontent.com/flathub/org.vinegarhq.Vinegar/e24cb9dfa996bcfeaa46504c0375660fe271148d/patches/wine/mouselock.patch";
          hash = "sha256-0AGA4AQbxTL5BGVbm072moav7xVA3zpotYqM8pcEDa4=";
        })
      ];
  });
in
buildGoModule rec {
  pname = " vinegar";
  version = " 1.7.3";

  src = fetchFromGitHub {
    owner = "vinegarhq";
    repo = "vinegar";
    rev = "v1.7.3";
    hash = "sha256-aKL+4jw/uMbbvLRCBHstCTrcQ1PTYSCwMNgXTvSvMeY=";
  };

  vendorHash = "sha256-OaMfWecOPQh6quXjYkZLyBDHZ9TINSA7Ue/Y0sz5ZYY=";

  nativeBuildInputs = [ pkg-config makeBinaryWrapper ];
  buildInputs = [ libGL libxkbcommon xorg.libX11 xorg.libXcursor xorg.libXfixes wayland vulkan-headers wine samba ];

  buildPhase = ''
    runHook preBuild
    make PREFIX=$out
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make PREFIX=$out install
    runHook postInstall
  '';

  postInstall = ''
    wrapProgram $out/bin/vinegar \
      --prefix PATH : ${lib.makeBinPath [wine samba]}
  '';

  meta = with lib; {
    description = "An open-source, minimal, configurable, fast bootstrapper for running Roblox on Linux";
    homepage = "https://github.com/vinegarhq/vinegar";
    changelog = "https://github.com/vinegarhq/vinegar/releases/tag/v${version}";
    mainProgram = "vinegar";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ nyanbinary ];
  };
}


