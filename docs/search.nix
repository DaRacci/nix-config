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
      inherit inputs lib;
      hostDirectory = "${self}/hosts";
      importExternals = false;
      users = [ ];
    };
    name = "rd-${name}";
    urlPrefix = "https://codeberg.org/Racci/nix-config/src/branch/master/";
  };

  rootModules =
    builtins.readDir "${self}/modules/nixos"
    |> lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists "${self}/modules/nixos/${name}/default.nix"
    )
    |> builtins.attrNames;
in
mkMultiSearch {
  title = "RacciDev Search";
  baseHref = "/nix-config/search/";
  scopes = rootModules |> map (path: mkRacciDevModule path "${self}/modules/nixos/${path}");
}
// {
  passthru.discovery = false;
}
