{
  self,
  pkgs,
  lib,
  search,
  ...
}:
pkgs.stdenv.mkDerivation (finalAttrs: {
  name = "raccidev-docs";
  __structuredAttrs = true;

  phase = [ "buildPhase" ];
  builtInputs = [ pkgs.mdbook ];

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      (lib.fileset.fileFilter (
        { type, hasExt, ... }:
        type == "regular"
        && lib.any hasExt [
          "css"
          "js"
          "md"
          "toml"
        ]
      ) ./.)
    ];
  };

  buildPhase = ''
    mkdir -p "$out"

    mv ./docs/* ./ && rmdir ./docs

    ${pkgs.fd}/bin/fd
    substituteInPlace ./src/index.md \
      --replace-fail "@README@" "$(cat ${finalAttrs.passthru.readme})"

    ${lib.getExe pkgs.mdbook} build
    cp -r ./book/* "$out"
    mkdir -p "$out/search"
    cp -r ${finalAttrs.passthru.search}/* "$out/search"
  '';

  passthru = {
    inherit search;
    readme =
      pkgs.runCommand "readme"
        {
          start = "<!-- START DOCS -->";
          end = "<!-- STOP DOCS -->";
          src = ../README.md;
        }
        ''
          # extract relevant section of the README
          sed -n "/$start/,/$end/p" $src > $out
        '';
  };
})
