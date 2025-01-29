{
  self,
  inputs,
  pkgs,
  lib,
}:
let
  wrapper =
    builder: system: name: args:
    import builder (
      args
      // {
        inherit
          self
          system
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
    mkHm = wrapper ./home/mkHm.nix;
    mkSystem = wrapper ./home/mkSystem.nix;
  };

  system = rec {
    mkRaw = wrapper ./system/mkRaw.nix;
    mkSystem = wrapper ./system/mkSystem.nix;
    mkIso = wrapper ./system/mkIso.nix;

    build =
      system: name: args:
      let
        raw = mkRaw system name args;
      in
      rec {
        system = mkSystem system name (args // { inherit raw; });
        image = system.config.formats.${args.isoFormat};
        # iso = mkIso system name (args // { inherit raw; });
      };
  };
}
