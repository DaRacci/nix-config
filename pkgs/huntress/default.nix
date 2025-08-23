{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
stdenv.mkDerivation rec {
  pname = "huntress";
  version = "0.14.74";

  src = fetchurl {
    url = "https://huntresscdn.com/huntress-installers/linux/amd64/${version}.tgz";
    sha256 = "sha256-NZJErHLIg0ECAqDWaf3U3xiTA5UXPdcrxsvNpVcdpHc=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/{bin,src}

    tar -xzf $src --strip-components=3 --directory $out/src
    ln -s $out/src/huntress-{agent,updater} $out/bin/
  '';

  meta = {
    description = "Huntress.";
    homepage = "https://huntress.io";

    platforms = lib.platforms.linux;
  };
}
