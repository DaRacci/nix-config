{
  self,
  moduleWithSystem,
  ...
}:
let
  mkModuleWithSystem =
    importFunc:
    moduleWithSystem (
      perSystem@{
        self,
        config,
        inputs,
        ...
      }:
      nixos@{
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
    // (builtins.mapAttrs (_: v: mkModuleWithSystem v) (import "${self}/modules/nixos"));

    homeManagerModules = import "${self}/modules/home-manager";

    flakeModules = import "${self}/modules/flake";
  };
}
