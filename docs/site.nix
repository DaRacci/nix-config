{
  pkgs,
  lib,
  search,
  moduleOptionsJSON,
  allModules,

  discoverModules,
  mkNixosModuleOptions,
  mkHomeManagerModuleOptions,
  ...
}:
let
  # Python script packaged as store path so it can be referenced by full path
  # inside sandbox without needing python3 in PATH.
  genOptionsMd = pkgs.writeText "gen-options-md.py" (
    builtins.readFile ./preprocessor/gen-options-md.py
  );
  py3 = "${pkgs.python3}/bin/python3";

  # Dynamically generate option fragments for all discovered modules
  optionFragments = lib.mapAttrsToList (name: module: {
    json = moduleOptionsJSON.${name};
    prefix = module.prefix;
    output = "generated/${module.outputName}-options.md";
  }) allModules;

  generateOptionFragments = lib.concatMapStringsSep "\n" (fragment: ''
    ${py3} ${genOptionsMd} \
      ${fragment.json} \
      "${fragment.prefix}" \
      ${fragment.output}
  '') optionFragments;

  mdBookRewriteLinks = pkgs.writers.writePython3Bin "mdbook-rewrite-links" {
    flakeIgnore = [
      "E265"
      "E501"
    ];
  } ./preprocessor/rewrite-links.py;
  mdBookValidateIncludes = pkgs.writers.writePython3Bin "mdbook-validate-includes" {
    flakeIgnore = [
      "E265"
      "E501"
    ];
  } ./preprocessor/validate-includes.py;

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
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  name = "raccidev-docs";
  __structuredAttrs = true;

  phase = [ "buildPhase" ];
  nativeBuildInputs = [
    pkgs.mdbook
    mdBookRewriteLinks
    mdBookValidateIncludes
  ];

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
          "py"
          "toml"
        ]

      ) ./.)
    ];
  };

  buildPhase = ''
    mkdir -p "$out"

    mv ./docs/* ./ && rmdir ./docs

    ${pkgs.fd}/bin/fd

    # ── Option reference fragments ───────────────────────────────────────
    # Generate Markdown fragments for all docs pages that embed module
    # options via {{#include}}.
    mkdir -p generated

    ${generateOptionFragments}

    # ── README substitution ───────────────────────────────────────────────
    substituteInPlace ./src/index.md \
      --replace-fail "@README@" "$(cat ${readme})"

    # ── Include validation ────────────────────────────────────────────────
    ${lib.getExe mdBookValidateIncludes}

    # ── Build the mdbook site ─────────────────────────────────────────────
    ${lib.getExe pkgs.mdbook} build

    cp -r ./book/* "$out"

    # ── Search static files ───────────────────────────────────────────────
    mkdir -p "$out/search"
    cp -r ${finalAttrs.passthru.search}/* "$out/search"

  '';

  passthru = {
    inherit
      search
      readme
      moduleOptionsJSON
      allModules
      discoverModules
      mkNixosModuleOptions
      mkHomeManagerModuleOptions
      ;
    discovery = false;
  };
})
