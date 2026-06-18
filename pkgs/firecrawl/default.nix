{
  lib,
  stdenv,
  fetchFromGitHub,
  pnpm,
  nodejs,
  makeBinaryWrapper,
  playwright-driver,
  ...
}:

let
  version = "2.10.25";
in
stdenv.mkDerivation {
  pname = "firecrawl";
  inherit version;

  src = fetchFromGitHub {
    owner = "firecrawl";
    repo = "firecrawl";
    rev = "v${version}";
    fetchSubmodules = false;
    sha256 = "sha256-c/mbNYZeJWF3YKhOutHHlwof/v0rSCtGe06bK28v/Dw=";
  };

  nativeBuildInputs = [
    pnpm.configHook
    nodejs
    makeBinaryWrapper
  ];

  pnpmRoot = "apps/api";

  buildPhase = ''
    runHook preBuild

    cd apps/api
    pnpm run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    cd ../..
    mkdir -p $out/share/firecrawl $out/bin
    cp -r apps/api/dist $out/share/firecrawl/
    cp -r apps/api/node_modules $out/share/firecrawl/
    cp apps/api/package.json $out/share/firecrawl/

    makeWrapper ${lib.getExe nodejs} $out/bin/firecrawl \
      --add-flags "$out/share/firecrawl/dist/src/harness.js" \
      --add-flags "--start-built" \
      --set-default PLAYWRIGHT_BROWSERS_PATH "${playwright-driver.browsers}" \
      --set-default PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD "1" \
      --set-default NODE_ENV "production"

    runHook postInstall
  '';

  meta = {
    description = "Turn entire websites into LLM-ready markdown or structured data";
    homepage = "https://github.com/firecrawl/firecrawl";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "firecrawl";
  };
}
