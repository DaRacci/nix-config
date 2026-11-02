{
  pkgs,
  excludes ? import ./excludes.nix,
}:
let
  # The single source of the rumdl configuration.
  # devenv writes it to the gitignored `.rumdl.toml` on shell entry, and the
  # flake packages it as `rumdl-config` for CI, where no dev shell is entered.
  settings = {
    global = {
      enable = [
        "MD001" # heading levels increment by one
        "MD011" # reversed link syntax
        "MD012" # no consecutive blank lines
        "MD036" # emphasis is not a heading
        "MD040" # fenced code declares a language
        "MD042" # no empty links
        "MD051" # fragments must reference existing headings
        "MD052" # reference links must be defined
        "MD053" # reference definitions must be used
        "MD057" # relative links must point to existing files
        "MD062" # no whitespace in link destinations
        "MD080" # heading anchors must be unique
      ];

      exclude = excludes;
    };

    # mdBook generates the search page at build time,
    # so the link to it has no source file to resolve against.
    per-file-ignores = {
      "docs/src/index.md" = [ "MD057" ];
      "docs/src/SUMMARY.md" = [ "MD057" ];
    };
  };

  config = (pkgs.formats.toml { }).generate "rumdl.toml" settings;
in
{
  inherit settings config;

  # Points rumdl at the packaged config so it does not depend on a
  # dev-shell-generated `.rumdl.toml` being present in the working tree.
  wrapper = pkgs.writeShellScriptBin "rumdl" ''
    exec ${pkgs.lib.getExe pkgs.rumdl} --config ${config} "$@"
  '';
}
