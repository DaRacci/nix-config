/*
  Inputs from the nixpkgs repo that are defined as a raw file URL.
  Example input:
  ```nix
  program = {
    url = "https://raw.githubusercontent.com/r-ryantm/nixpkgs/refs/heads/auto-update/package/pkgs/by-name/pa/package/package.nix";
    flake = false;
    type = "file";
  };
  ```

  These inputs can optionally be a nameValuePair with the name of the input and
  function to use instead of `pkgs.callPackage`.
  Example for python packages:
  `(nameValuePair "package" (pkgs: pkgs.python3Packages.callPackage))`
*/
{
  inputs,
  lib,
}:
let
  inherit (lib)
    isAttrs
    isString
    foldl'
    nameValuePair
    recursiveUpdate
    callPackageWith
    ;

  singletonInputs = [
    "tabby"
    "tabby-agent"
    "hyprlandPlugins.hy3"
  ];

  isNestedName = name: lib.strings.match ".*\\..*" name != null;

  # Split a dotted name into parts
  splitName = name: lib.filter (x: x != "" && x != [ ]) (builtins.split "\\." name);

  # Build nested attribute structure from parts and value
  buildNested =
    parts: value:
    if parts == [ ] then
      value
    else
      { ${builtins.head parts} = buildNested (builtins.tail parts) value; };

  singletonPkgs = map (
    input:
    if isAttrs input && input ? name && input ? value then
      input
    else if isString input then
      nameValuePair input (
        if isNestedName input then
          # For nested packages, get parent scope
          (
            pkgs:
            let
              parts = splitName input;
              parentPath = lib.take (builtins.length parts - 1) parts;
              parentScope = lib.attrByPath parentPath { } pkgs;
            in
            callPackageWith (pkgs // parentScope) inputs.${input} { }
          )
        else
          (pkgs: pkgs.callPackage inputs.${input} { })
      )
    else
      throw "Invalid input format for singleton input ${toString input}."
  ) singletonInputs;
in
final: prev:
let
  # Separate nested from flat packages
  nestedInputs = builtins.filter (s: isNestedName s.name) singletonPkgs;
  flatInputs = builtins.filter (s: !isNestedName s.name) singletonPkgs;

  # Build flat packages normally
  flatAttrs = foldl' (
    acc: singleton:
    let
      pkg = singleton.value final;
    in
    acc // { ${singleton.name} = pkg; }
  ) { } flatInputs;

  # Build nested packages and merge into their parent sets
  nestedAttrs = foldl' (
    acc: singleton:
    let
      parts = splitName singleton.name;
      pkg = singleton.value final;
      parentPath = lib.take (builtins.length parts - 1) parts;
      childName = lib.last parts;
      nestedStructure = buildNested parentPath { ${childName} = pkg; };
    in
    recursiveUpdate acc nestedStructure
  ) { } nestedInputs;
in
recursiveUpdate prev (flatAttrs // nestedAttrs)
