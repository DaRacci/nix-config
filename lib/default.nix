{ self, system, inputs }:
let
  pkgsFor = system: inputs.nixpkgs.legacyPackages.${system};

  wrapper = builder: system: name: args: import builder (args // {
    inherit self system pkgsFor name inputs;
  });
  simpleWrapper = builder: system: name: wrapper builder system name { };

  wrapperPair = builder: system: name: args: inputs.nixpkgs.lib.nameValuePair name (wrapper builder system name args);
  simpleWrapperPair = builder: system: name: inputs.nixpkgs.lib.nameValuePair name (simpleWrapper builder system name);

  simpleImport = path: import path {
    inherit pkgsFor inputs system;
  };
in
{
  lib = {
    attrsets = simpleImport ./attrsets.nix;
    hardware = simpleImport ./hardware.nix;
  };

  shell = {
    mkNix = simpleWrapperPair ./builders/shell/mkDevShellNix.nix;
    mkRust = wrapperPair ./builders/shell/mkDevShellRust.nix;
  };

  home = {
    mkHm = wrapper ./builders/home/mkHm.nix;
    mkSystem = wrapper ./builders/home/mkSystem.nix;
  };

  system = rec {
    mkRaw = wrapper ./builders/system/mkRaw.nix;
    mkSystem = wrapper ./builders/system/mkSystem.nix;
    mkIso = wrapper ./builders/system/mkIso.nix;

    build = system: name: args:
      let raw = mkRaw system name args; in {
        system = mkSystem system name (args // { inherit raw; });
        iso = mkIso system name (args // { inherit raw; });
      };
  };
}
