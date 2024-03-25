{ lib
, stdenvNoCC
, fetchFromGitHub
, makeWrapper

, socat
, gojq
}:

stdenvNoCC.mkDerivation rec {
  pname = "hyprland-smart-borders";
  version = "unstable-2024-01-11";

  src = fetchFromGitHub {
    owner = "devadathanmb";
    repo = "hyprland-smart-borders";
    rev = "05cd98291f0a8aabe2404a9aa16f1048df1abd2f";
    hash = "sha256-kxj9Fubuj6OUfaBw8mJyVxyUqtH0wLnmgc1DQIxmdSE=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  postPatch = ''
    substituteInPlace dynamic-borders.sh \
      --replace 'jq' 'gojq'
  '';

  installPhase = ''
    mkdir -p $out/bin
    
    cp dynamic-borders.sh $out/bin/hyprland-smart-borders
    chmod +x $out/bin/hyprland-smart-borders
  '';

  postInstall = ''
    wrapProgram $out/bin/hyprland-smart-borders \
      --prefix PATH ':' ${lib.makeBinPath [ socat gojq ]}
  '';

  meta = with lib; {
    description = "A pure bash script using hyprland-ipc to enable smart borders (dynamic borders) in hyprland";
    homepage = "https://github.com/devadathanmb/hyprland-smart-borders";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ racci ];
    mainProgram = "hyprland-smart-borders";
    platforms = platforms.unix;
  };
}
