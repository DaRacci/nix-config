{
  self,
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions

    ./modules.nix
    ./packages.nix

    ../modules/flake
  ];

  partitions = {
    ci = {
      extraInputsFlake = ./ci;
      module = ./ci/flake-module.nix;
    };
    dev = {
      extraInputsFlake = ./dev;
      module = ./dev/flake-module.nix;
    };
    docs = {
      extraInputsFlake = ./docs;
      module = ./docs/flake-module.nix;
      extraInputs = config.partitions.home-manager.extraInputs // config.partitions.nixos.extraInputs;
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
    githubActions = "ci";
  }
  // (lib.genAttrs [
    "checks"
    "devShells"
    "formatter"
  ] (_: "dev"));

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = lib.builders.mkPkgs { inherit system; };
    };
}
