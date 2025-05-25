{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage {
  pname = "github-actions-mcp-server";
  version = "unstable-2025-05-15";

  src = fetchFromGitHub {
    owner = "ko1ynnky";
    repo = "github-actions-mcp-server";
    rev = "33bda39edd05f670853cd6d7808b99b48e69dc9e";
    hash = "sha256-vp4voJQL7pFUjYl//g9MuOtG9s3wYcaEXgD9IcnrTiM=";
  };

  npmDepsHash = "sha256-wlKUgkFcIcgFMyiLmUmg0FT7CWOichVbWVSCTvBrXrs=";
  NODE_OPTIONS = "";

  prePatch = ''
    REPLACEMENT=$(cat << EOF
    const userCacheDir = process.env.HOME as string;
    const logFilePath = path.join(userCacheDir, '.cache', 'github-actions-mcp-server', 'mcp-startup.log');
    EOF
    )
    substituteInPlace src/index.ts \
      --replace-fail "const logFilePath = path.join(__dirname, '..', 'dist', 'mcp-startup.log');" "$REPLACEMENT"
  '';

  meta = {
    description = "GitHub Actions Model Context Protocol Server";
    homepage = "https://github.com/ko1ynnky/github-actions-mcp-server?tab=readme-ov-file";
    license = lib.licenses.unfree; # FIXME: nix-init did not find a license
    maintainers = with lib.maintainers; [ ];
    mainProgram = "github-actions-mcp";
    platforms = lib.platforms.all;
  };
}
