{
  pkgs,
  lib,
  search,
  aiAgentOptionsJSON,
  huntressOptionsJSON,
  mcpoOptionsJSON,
  metricsOptionsJSON,
  tailscaleOptionsJSON,
  woodpeckerNixOptionsJSON,
  diyPrintingOptionsJSON,
  ...
}:
let
  # Python scripts packaged as store paths so they can be referenced by
  # full path inside the sandbox without needing python3 in PATH.
  genOptionsMd = pkgs.writeText "gen-options-md.py" (builtins.readFile ./gen-options-md.py);
  genOptionsJson = pkgs.writeText "gen-options-json.py" (builtins.readFile ./gen-options-json.py);
  py3 = "${pkgs.python3}/bin/python3";

  optionFragments = [
    {
      json = aiAgentOptionsJSON;
      prefix = "services.ai-agent";
      output = "src/generated/ai-agent-options.md";
    }
    {
      json = huntressOptionsJSON;
      prefix = "services.huntress";
      output = "src/generated/huntress-options.md";
    }
    {
      json = mcpoOptionsJSON;
      prefix = "services.mcpo";
      output = "src/generated/mcpo-options.md";
    }
    {
      json = metricsOptionsJSON;
      prefix = "services.metrics";
      output = "src/generated/metrics-options.md";
    }
    {
      json = tailscaleOptionsJSON;
      prefix = "services.tailscale";
      output = "src/generated/tailscale-options.md";
    }
    {
      json = woodpeckerNixOptionsJSON;
      prefix = "services.woodpeckerNix";
      output = "src/generated/woodpecker-nix-options.md";
    }

    {
      json = diyPrintingOptionsJSON;
      prefix = "purpose.diy.printing";
      output = "src/generated/diy-printing-options.md";
    }
  ];

  generateOptionFragments = lib.concatMapStringsSep "\n" (fragment: ''
    ${py3} ${genOptionsMd} \
      ${fragment.json} \
      "${fragment.prefix}" \
      ${fragment.output}
  '') optionFragments;
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

    # ── Option reference fragments ───────────────────────────────────────
    # Generate Markdown fragments for all docs pages that embed module
    # options via {{#include}}.
    mkdir -p src/generated
    ${generateOptionFragments}

    # ── README substitution ───────────────────────────────────────────────
    substituteInPlace ./src/index.md \
      --replace-fail "@README@" "$(cat ${finalAttrs.passthru.readme})"

    # ── Build the mdbook site ─────────────────────────────────────────────
    ${lib.getExe pkgs.mdbook} build
    cp -r ./book/* "$out"

    # ── Search static files ───────────────────────────────────────────────
    mkdir -p "$out/search"
    cp -r ${finalAttrs.passthru.search}/* "$out/search"

    # ── Search-side option JSON ──────────────────────────────────────────
    # Keep generating the slim JSON blob for the search bundle so the
    # client-side widget remains available where needed.
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
