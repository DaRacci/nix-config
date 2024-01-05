{ ... }@inputs:
let
  systemPkgs = inputs.flake-utils.lib.eachDefaultSystem (system: import inputs.nixpkgs { inherit system; });
  pkgsFor = name: system: systemPkgs.${system};

  wrapper = builder: system: name: args: inputs.nixpkgs.lib.nameValuePair name (import builder (args // {
    inherit system pkgsFor name;
  }));
  simpleWrapper = builder: system: name: args: wrapper builder system name args { };
in
{
  mkDevShell = simpleWrapper ./builders/mkDevShell.nix;
  mkDevShellRust = wrapper ./builders/mkDevShellRust.nix;
}# // simpleWrapper ./attrsets.nix // simpleWrapper ./hardware.nix
