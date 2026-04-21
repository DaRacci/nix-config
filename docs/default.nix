{
  self,
  inputs,
  system,
  pkgs,
  lib,
  ...
}:
let
  inherit (inputs.search.packages.${system}) mkOptionsJSON;

  # Build a minimal module evaluation suitable for options documentation.
  # Mirrors the pattern used in search.nix so the same specialArgs are
  # available to every module under modules/nixos.
  mkModuleOptions =
    path:
    mkOptionsJSON {
      modules = [
        path
        {
          _module.args = {
            inherit self inputs pkgs;
          };
        }
      ];
      specialArgs = {
        inherit inputs;
        users = [ ];
      };
    };
in
rec {
  search = pkgs.callPackage ./search.nix {
    inherit
      self
      inputs
      system
      pkgs
      ;
    lib = pkgs.lib;
  };

  # options.json for individual modules – used by site.nix to generate
  # inline option reference docs (build-time) and client-side widgets.
  woodpeckerNixOptionsJSON = mkModuleOptions "${self}/modules/nixos/services/woodpecker-nix.nix";
  tailscaleOptionsJSON = mkModuleOptions "${self}/modules/nixos/services/tailscale.nix";

  docs = pkgs.callPackage ./site.nix {
    inherit
      self
      inputs
      pkgs
      lib
      search
      woodpeckerNixOptionsJSON
      tailscaleOptionsJSON
      ;
  };

  serve-docs = pkgs.callPackage ./serve.nix {
    inherit docs;
  };
}
