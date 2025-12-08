{
  inputs,
  lib,
}:
let
  mkPkgs =
    {
      system ? "x86_64-linux",
      accelerators ? [ ],
      ...
    }@args:
    import inputs.nixpkgs (
      {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
          permittedInsecurePackages = [ ];

          cudaSupport = builtins.elem "cuda" accelerators;
          rocmSupport = builtins.elem "rocm" accelerators;
        };

        overlays = [
          inputs.lix-module.overlays.default
        ]
        ++ (builtins.attrValues (import ../../overlays { inherit inputs lib; }));
      }
      // (builtins.removeAttrs args [
        "system"
        "accelerators"
        "overlays"
        "inputs"
      ])
    );

  wrapper =
    builder: name:
    args@{
      accelerators ? [ ],
      system ? "x86_64-linux",
      ...
    }:
    import builder (
      {
        inherit
          name
          inputs
          lib
          ;

        pkgs = mkPkgs { inherit system accelerators; };
      }
      // (removeAttrs args [
        "accelerators"
        "system"
      ])
    );
in
{
  inherit mkPkgs;

  readDirNoCommons =
    dir:
    builtins.readDir dir
    |> builtins.attrNames
    |> builtins.filter (name: name != "shared")
    |> builtins.filter (name: name != "secrets.yaml");

  home = {
    mkHomeManager = wrapper ./home/mkHomeManager.nix;
    mkSystem = wrapper ./home/mkSystem.nix;
  };

  mkSystem = name: args: wrapper ./mkSystem.nix name args;
}
