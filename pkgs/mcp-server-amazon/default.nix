{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  nix-update-script,
  makeWrapper,
  chromium,
  nodejs,
}:
buildNpmPackage (_: {
  pname = "mcp-server-amazon";
  version = "0-unstable-2025-07-25";

  src = fetchFromGitHub {
    owner = "rigwild";
    repo = "mcp-server-amazon";
    rev = "c2ad8d60bcde54c4444e98b6ec1201688650e403";
    hash = "sha256-wHUQn4eOhqCJBm9EU7N51++XHGPS+9COOnqDzURk/Ww=";
  };

  npmDepsHash = "sha256-5G6w/SL/HHu17HgMx26nt4VuupvMp2ui/tYRQbtSL5M=";
  nativeBuildInputs = [ makeWrapper ];
  doCheck = false;

  env.PUPPETEER_SKIP_DOWNLOAD = "true";

  postPatch = ''
    substituteInPlace src/config.ts \
      --replace-fail '`''${__dirname}/../amazonCookies.json`' 'process.env.AMAZON_COOKIES_PATH as string'
  '';

  postInstall = ''
    makeWrapper "${nodejs}/bin/node" "$out/bin/mcp-server-amazon" \
      --add-flags "$out/lib/node_modules/mcp-server-amazon/build/index.js" \
      --set PUPPETEER_EXECUTABLE_PATH "${lib.getExe chromium}"
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--version=branch"
    ];
  };

  meta = {
    description = "Unofficial Amazon Model Context Protocol Server (MCP) - Search products and purchase directly from Claude AI";
    homepage = "https://github.com/rigwild/mcp-server-amazon";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ racci ];
    mainProgram = "mcp-server-amazon";
    platforms = lib.platforms.all;
  };
})
