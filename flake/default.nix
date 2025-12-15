{
  inputs,
  lib,
  config,
  ...
}:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions

    ./modules.nix
    ./packages.nix
  ];

  partitions = {
    dev = {
      extraInputsFlake = ./dev;
      module = ./dev/flake-module.nix;
    };
    home-manager = {
      extraInputsFlake = ./home-manager;
      module = ./home-manager/flake-module.nix;
    };
    nixos = {
      extraInputsFlake = ./nixos;
      module = ./nixos/flake-module.nix;
      extraInputs = builtins.removeAttrs config.partitions.home-manager.extraInputs [
        "nixpkgs"
        "systems"
        "flake-parts"
        "flake-utils"
      ];
    };
  };

  partitionedAttrs = {
    nixosConfigurations = "nixos";
    homeConfigurations = "home-manager";
  }
  // (lib.genAttrs [
    "checks"
    "ci"
    "devShells"
    "formatter"
  ] (_: "dev"));

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = lib.builders.mkPkgs { inherit system; };
    };
}
