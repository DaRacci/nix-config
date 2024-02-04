{
  description = "The nix-config of an Idiot";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://racci.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "racci.cachix.org-1:Kl4opLxvTV9c77DpoKjUOMLDbCv6wy3GVHWxB384gxg="
    ];
  };

  inputs = {
    # Packages
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-23.11"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nur = { url = "github:nix-community/NUR"; };

    # Utils
    flake-utils = { url = "github:numtide/flake-utils"; };
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    nixos-generators = { url = "github:nix-community/nixos-generators"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Base Modules
    home-manager = { url = "github:nix-community/home-manager/release-23.11"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware = { url = "github:nixos/nixos-hardware"; };
    nixos-wsl = { url = "github:nix-community/NixOS-WSL"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence = { url = "github:nix-community/impermanence"; };
    lanzaboote = { url = "github:nix-community/lanzaboote/v0.3.0"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-ld-rs = { url = "github:nix-community/nix-ld-rs"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Other misc modules
    arion = { url = "github:hercules-ci/arion"; };
    nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; };

    # DevShell modules
    pre-commit = { url = "github:cachix/pre-commit-hooks.nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    cocogitto = { url = "github:DaRacci/cocogitto"; inputs.nixpkgs.follows = "nixpkgs"; };
    fenix = { url = "github:nix-community/fenix"; inputs.nixpkgs.follows = "nixpkgs"; };
    getchoo = { url = "github:getchoo/nix-exprs"; };
  };

  outputs = { self, nixpkgs, flake-utils, systems, getchoo, nixos-wsl, nixos-generators, ... }@inputs:
    let
      inherit (self) outputs;
      inherit (nixpkgs.lib) listToAttrs;
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          lib = import ./lib { inherit self inputs system; };
          inherit (lib.shell) mkNix mkRust;

          homeConfigurations = builtins.mapAttrs (n: v: lib.home.mkHm system n v) {
            racci = { };
          };

          configurations = builtins.mapAttrs (n: v: lib.system.build system n v) {
            nixe = {
              deviceType = "desktop";
              isoFormat = "iso";
              users = [ "racci" ];
            };

            surnix = {
              deviceType = "laptop";
              isoFormat = "iso";
              users = [ "racci" ];
            };

            winix = {
              deviceType = "desktop";
              isoFormat = "iso";
              users = [ "racci" ];
            };

            nixcloud = {
              deviceType = "server";
              isoFormat = "proxmox-lxc";
            };
          };
        in
        {
          nixosConfigurations = builtins.mapAttrs (n: v: v.system) configurations;
          homeConfigurations = builtins.mapAttrs (n: v: inputs.home-manager.lib.homeManagerConfiguration v) homeConfigurations;

          devShells = listToAttrs [
            (mkNix system "default")
            (mkRust system "rust-stable" { rustChannel = "stable"; })
            (mkRust system "rust-nightly" { rustChannel = "nightly"; })
          ];

          packages = lib.lib.attrsets.recursiveMergeAttrs [
            (import ./pkgs { pkgs = nixpkgs.legacyPackages.${system}; inherit system getchoo; })

            {
              # Image Generators
              images = (builtins.mapAttrs (n: v: v.iso) configurations);

              # NixOS Outputs
              outputs = (builtins.mapAttrs (n: v: v.system.config.system.build.toplevel) configurations);
            }
          ];

          checks = { };
          formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
          overlays = import ./overlays { pkgs = nixpkgs.legacyPackages.${system}; inherit self inputs system outputs getchoo; };
        }) // {
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;
    };
}
