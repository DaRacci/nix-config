{
  self,
  inputs,
  system,
  pkgs,
  lib,
  ...
}:
let
  inherit (inputs.search.packages.${system}) mkMultiSearch;

  mkRacciDevModule = name: path: {
    modules = [
      path
      { _module.args = { inherit self inputs pkgs; }; }
    ];
    specialArgs = {
      inherit inputs;
      users = [ ];
    };
    name = "rd-${name}";
    urlPrefix = "https://github.com/DaRacci/nix-config/blob/master/";
  };

  rootModules =
    builtins.readDir "${self}/modules/nixos"
    |> lib.filterAttrs (_: type: type == "directory")
    |> builtins.attrNames;
in
mkMultiSearch {
  title = "RacciDev Search";
  baseHref = "/search/";
  scopes = rootModules |> map (path: mkRacciDevModule path "${self}/modules/nixos/${path}");
}
