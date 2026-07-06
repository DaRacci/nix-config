{
  lib,
  nix-update-script,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
}:
buildPythonPackage (attrs: {
  pname = "rtk-hermes";
  version = "1.2.3";
  src = fetchFromGitHub {
    owner = "ogallotti";
    repo = "rtk-hermes";
    rev = "v${attrs.version}";
    hash = "sha256-7YRW6PODrCapfYLFn3DvgHAEME//RGC48GQt+s9ot0s=";
  };

  pyproject = true;

  build-system = [ setuptools ];

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Hermes plugin that rewrites terminal commands through RTK for lower-context tool output";
    homepage = "https://github.com/ogallotti/rtk-hermes";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.racci ];
  };
})
