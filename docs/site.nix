{
  pkgs,
  lib,
  search,
  woodpeckerNixOptionsJSON,
  tailscaleOptionsJSON,
  ...
}:
let
  # Python scripts packaged as store paths so they can be referenced by
  # full path inside the sandbox without needing python3 in PATH.
  genOptionsMd = pkgs.writeText "gen-options-md.py" (builtins.readFile ./gen-options-md.py);
  genOptionsJson = pkgs.writeText "gen-options-json.py" (builtins.readFile ./gen-options-json.py);
  py3 = "${pkgs.python3}/bin/python3";
in
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

    # ── Option 1: build-time Markdown generation ─────────────────────────
    # Generate a Markdown fragment for the woodpecker-nix Reference section.
    # woodpecker-nix.md includes this via {{#include}}.
    mkdir -p src/generated
    ${py3} ${genOptionsMd} \
      ${woodpeckerNixOptionsJSON} \
      "services.woodpeckerNix" \
      src/generated/woodpecker-nix-options.md

    # ── README substitution ───────────────────────────────────────────────
    substituteInPlace ./src/index.md \
      --replace-fail "@README@" "$(cat ${finalAttrs.passthru.readme})"

    # ── Build the mdbook site ─────────────────────────────────────────────
    ${lib.getExe pkgs.mdbook} build
    cp -r ./book/* "$out"

    # ── Search static files ───────────────────────────────────────────────
    mkdir -p "$out/search"
    cp -r ${finalAttrs.passthru.search}/* "$out/search"

    # ── Option 2: client-side widget JSON ────────────────────────────────
    # Generate a slim JSON blob consumed by nix-options.js on the page.
    mkdir -p "$out/search/module-options"
    ${py3} ${genOptionsJson} \
      ${woodpeckerNixOptionsJSON} \
      "services.woodpeckerNix" \
      "$out/search/module-options/woodpecker-nix.json"
  '';

  passthru = {
    inherit search;
    discovery = false;
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
