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
      # Stylix fixes
      {
        # options.programs = { }; # Stylix uses this unconditionally and it causes an error if it's not defined
        disabledModules = [ "${inputs.stylix.nixosModules.stylix._file}" ];
      }
    ];
    specialArgs = {
      inherit inputs lib;
      users = [ ];
    };
    name = "rd-${name}";
    urlPrefix = "https://codeberg.org/Racci/nix-config/src/branch/master/";
  };

  rootModules =
    builtins.readDir "${self}/modules/nixos"
    |> lib.filterAttrs (_: type: type == "directory")
    |> builtins.attrNames;
in
mkMultiSearch {
  title = "RacciDev Search";
  baseHref = "/nix-config/search/";
  scopes = rootModules |> map (path: mkRacciDevModule path "${self}/modules/nixos/${path}");
}
