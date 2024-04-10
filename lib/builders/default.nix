{ self
, inputs
, pkgs
, lib
}:
let
  wrapper = builder: system: name: args: import builder (args // {
    inherit self system name inputs lib pkgs;
  });
  simpleWrapper = builder: system: name: wrapper builder system name { };

  wrapperPair = builder: system: name: args: lib.nameValuePair name (wrapper builder system name args);
  simpleWrapperPair = builder: system: name: lib.nameValuePair name (simpleWrapper builder system name);
in
{
  shell = {
    mkNix = simpleWrapperPair ./shell/mkDevShellNix.nix;
    mkRust = wrapperPair ./shell/mkDevShellRust.nix;
  };

  home = {
    mkHm = wrapper ./home/mkHm.nix;
    mkSystem = wrapper ./home/mkSystem.nix;
  };

  system = rec {
    mkRaw = wrapper ./system/mkRaw.nix;
    mkSystem = wrapper ./system/mkSystem.nix;
    mkIso = wrapper ./system/mkIso.nix;

    build = system: name: args:
      let raw = mkRaw system name args; in rec {
        system = mkSystem system name (args // { inherit raw; });
        image = system.config.formats.${args.isoFormat};
        # iso = mkIso system name (args // { inherit raw; });
      };
  };
}
