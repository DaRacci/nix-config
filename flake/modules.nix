{
  self,
  moduleWithSystem,
  ...
}:
let
  mkModuleWithSystem =
    importFunc:
    moduleWithSystem (
      {
        self,
        config,
        inputs,
        ...
      }:
      {
        pkgs,
        lib,
        users,
        ...
      }:
      importFunc {
        inherit
          self
          inputs
          config
          lib
          pkgs
          users
          ;
      }
    );
in
{
  flake = {
    nixosModules = {
      server = mkModuleWithSystem (import "${self}/modules/nixos/server");
    }
    // (builtins.mapAttrs (_: mkModuleWithSystem) (import "${self}/modules/nixos"));

    homeManagerModules = import "${self}/modules/home-manager";

    flakeModules = import "${self}/modules/flake";
  };
}
