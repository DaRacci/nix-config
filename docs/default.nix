{
  self,
  inputs,
  system,
  pkgs,
  lib,
  ...
}:
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

  docs = pkgs.callPackage ./site.nix {
    inherit
      self
      inputs
      pkgs
      lib
      search
      ;
  };

  serve-docs = pkgs.callPackage ./serve.nix {
    inherit docs;
  };
}
