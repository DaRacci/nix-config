{ ... }@inputs:
let
  pkgsFor = system: inputs.nixpkgs.legacyPackages.${system};

  wrapper = builder: system: name: args: inputs.nixpkgs.lib.nameValuePair name (import builder (args // {
    inherit system pkgsFor name;
  }));
  simpleWrapper = builder: system: name: args: wrapper builder system name args { };
in
{
  mkDevShell = simpleWrapper ./builders/mkDevShell.nix;
  mkDevShellRust = wrapper ./builders/mkDevShellRust.nix;
}# // simpleWrapper ./attrsets.nix // simpleWrapper ./hardware.nix
