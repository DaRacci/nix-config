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
  mkNixosModuleOptions =
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

  # Build a minimal Home Manager module evaluation suitable for options
  # documentation.
  mkHomeManagerModuleOptions =
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
  aiAgentOptionsJSON = mkNixosModuleOptions "${self}/modules/nixos/services/ai-agent.nix";
  huntressOptionsJSON = mkNixosModuleOptions "${self}/modules/nixos/services/huntress.nix";
  mcpoOptionsJSON = mkNixosModuleOptions "${self}/modules/nixos/services/mcpo.nix";
  metricsOptionsJSON = mkNixosModuleOptions "${self}/modules/nixos/services/metrics.nix";
  tailscaleOptionsJSON = mkNixosModuleOptions "${self}/modules/nixos/services/tailscale.nix";
  woodpeckerNixOptionsJSON = mkNixosModuleOptions "${self}/modules/nixos/services/woodpecker-nix.nix";

  diyPrintingOptionsJSON = mkHomeManagerModuleOptions "${self}/modules/home-manager/purpose/diy/printing.nix";

  docs = pkgs.callPackage ./site.nix {
    inherit
      self
      inputs
      pkgs
      lib
      search
      aiAgentOptionsJSON
      huntressOptionsJSON
      mcpoOptionsJSON
      metricsOptionsJSON
      tailscaleOptionsJSON
      woodpeckerNixOptionsJSON
      diyPrintingOptionsJSON
      ;
  };

  serve-docs = pkgs.callPackage ./serve.nix {
    inherit docs;
  };
}
