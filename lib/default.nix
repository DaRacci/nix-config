{ ... }@inputs:
let
  pkgsFor = system: inputs.nixpkgs.legacyPackages.${system};

  wrapper = builder: system: name: args: inputs.nixpkgs.lib.nameValuePair name (import builder (args // {
    inherit system pkgsFor name inputs;
  }));
  simpleWrapper = builder: system: name: wrapper builder system name { };

  # desktopWrapper = builder: wayland: xorg: additional: inputs.nixpkgs.lib.foldl' inputs.nixpkgs.lib.recursiveUpdate { } [
  #   # (import ./builders/desktop/mkDesktop.nix)
  #   (import builder)
  #   additional
  # ];

  simpleImport = path: import path {
    system = builtins.currentSystem;
    inherit pkgsFor inputs;
  };
in
{
  lib = {
    attrsets = simpleImport ./attrsets.nix;
    hardware = simpleImport ./hardware.nix;
  };

  shell = {
    mkNix = simpleWrapper ./builders/shell/mkDevShellNix.nix;
    mkRust = wrapper ./builders/shell/mkDevShellRust.nix;
  };
}
