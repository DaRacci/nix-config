{
  self,
  inputs,
  pkgs,
  lib,
}:
let
  wrapper =
    builder: name: args:
    import builder (
      args
      // {
        inherit
          self
          name
          inputs
          lib
          pkgs
          ;
      }
    );
in
{
  home = {
    mkHomeManager = wrapper ./home/mkHomeManager.nix;
    mkSystem = wrapper ./home/mkSystem.nix;
  };

  mkSystem = name: args: wrapper ./mkSystem.nix name args;
}
