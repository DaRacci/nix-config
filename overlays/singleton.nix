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
    ;

  singletonInputs = [
    "tabby"
    "tabby-agent"
  ];

  singletonPkgs = map (
    input:
    if isAttrs input && input ? name && input ? value then
      nameValuePair input.name (pkgs: input.value pkgs inputs.${input.name} { })
    else if isString input then
      nameValuePair input (pkgs: pkgs.callPackage inputs.${input} { })
    else
      throw "Invalid input format for singleton input ${toString input}."
  ) singletonInputs;
in
_final: prev:
foldl' (
  acc: singleton:
  let
    pkg = singleton.value prev;
  in
  acc // { ${singleton.name} = pkg; }
) { } singletonPkgs
