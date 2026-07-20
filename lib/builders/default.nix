{
  inputs,
  lib,
}:
let
  inherit (lib) listToAttrs nameValuePair;

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
          permittedInsecurePackages = [
            #TODO:https://github.com/bitwarden/clients/pull/20448
            "electron-39.8.10"

            #TODO:Decky loader requirement, remove when possible
            "pnpm-9.15.9"
          ];

          cudaSupport = builtins.elem "cuda" accelerators;
          rocmSupport = builtins.elem "rocm" accelerators;
        };

        overlays = builtins.attrValues (import ../../overlays { inherit inputs lib; });
      }
      // (removeAttrs args [
        "system"
        "accelerators"
        "overlays"
        "inputs"
      ])
    );

  wrapper =
    builder: name:
    args@{
      allocations ? null,
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

        pkgs = mkPkgs (
          {
            inherit system;
          }
          // (lib.optionalAttrs (allocations != null) {
            accelerators = allocations.accelerators.${name} or [ ];
          })
        );
      }
      // (removeAttrs args [
        "system"
      ])
    );
in
rec {
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

  getHostsByType =
    self:
    readDirNoCommons "${self}/hosts"
    |> map (deviceType: nameValuePair deviceType (readDirNoCommons "${self}/hosts/${deviceType}"))
    |> listToAttrs;
}
