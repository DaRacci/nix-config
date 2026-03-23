# This was mostly just taken from https://github.com/Mic92/nix-update/blob/main/nix_update/eval.nix
{
  importPath,
  attribute,
  system ? builtins.currentSystem,
}:

let
  inherit (builtins)
    getFlake
    stringLength
    substring
    foldl'
    fromJSON
    ;

  # Parse the attribute path from JSON string
  attributePath = fromJSON attribute;
  # In case of flakes, we must pass a url with git attrs of the flake
  # otherwise the entire directory is copied to nix store
  flakeOrImportPath = importPath;

  # Try to navigate nested attributes, returning { success = bool; value = ...; }
  tryGetAttrPath =
    attrPath: root:
    foldl'
      (
        acc: attr:
        if acc.success && acc.value ? ${attr} then
          {
            success = true;
            value = acc.value.${attr};
          }
        else
          {
            success = false;
            value = null;
          }
      )
      {
        success = true;
        value = root;
      }
      attrPath;

  flake = getFlake flakeOrImportPath;

  pkg =
    let
      packages = flake.packages.${system} or { };
      # Try packages.${system} first, fall back to flake root if attribute not found
      packagesResult = tryGetAttrPath attributePath packages;
    in
    if packagesResult.success then packagesResult.value else (tryGetAttrPath attributePath flake).value;

  sanitizePosition =
    let
      outPath = flake.outPath;
      outPathLen = stringLength outPath;
    in
    { file, ... }@pos:
    if substring 0 outPathLen file != outPath then
      throw "${file} is not in ${outPath}"
    else
      pos // { file = importPath + substring outPathLen (stringLength file - outPathLen) file; };

  positionFromMeta =
    pkg:
    let
      parts = builtins.match "(.*):([0-9]+)" pkg.meta.position;
    in
    {
      file = builtins.elemAt parts 0;
      line = builtins.fromJSON (builtins.elemAt parts 1);
    };

  position =
    if (builtins.unsafeGetAttrPos "src" pkg) != null then
      sanitizePosition (builtins.unsafeGetAttrPos "src" pkg)
    else
      sanitizePosition (positionFromMeta pkg);

  eval = builtins.tryEval position.file;
in
if eval.success then
  eval.value
else
  builtins.addErrorContext "Unable to evaluate file or extract position from meta, returning null" null
