{
  description = "The nix-config of an Idiot";

  nixConfig = {
    extra-substituters = [ "https://racci.cachix.org" ];
    extra-trusted-public-keys = [ "racci.cachix.org-1:Kl4opLxvTV9c77DpoKjUOMLDbCv6wy3GVHWxB384gxg=" ];
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
      forEachSystem = nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ];

      inherit (self) outputs;
      inherit (nixpkgs.lib) listToAttrs;
      inherit (import ./lib/mk.nix inputs) mkHomeManagerConfiguration mkConfigurations;
      inherit ((import ./lib inputs).shell) mkNix mkRust;

      configurations = builtins.mapAttrs mkConfigurations {
        nixe = {
          role = "desktop";
          isoFormat = "iso";
          users = {
            racci = {
              extraHome = { pkgs }: {
                shell = pkgs.nushell;
              };
            };
          };
        };

        surnix = {
          role = "laptop";
          isoFormat = "iso";
          users = {
            racci = { };
          };
        };

        winix = {
          role = "desktop";
          isoFormat = "iso";
          users = {
            racci.extraHome = { pkgs }: { shell = pkgs.nushell; };
          };
        };

        nixcloud = {
          role = "server";
          isoFormat = "proxmox-lxc";
        };
      };
    in
    {
      nixosConfigurations = builtins.mapAttrs (n: v: v.nixosSystem) configurations;

      homeConfigurations = listToAttrs [
        (mkHomeManagerConfiguration { racci = { }; })
      ];

      devShells = forEachSystem (system: listToAttrs [
        (mkNix system "default")
        (mkRust system "rust-stable" { rustChannel = "stable"; })
        (mkRust system "rust-nightly" { rustChannel = "nightly"; })
      ]);

      checks = forEachSystem (system: { });

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);

      packages = nixpkgs.lib.foldl' nixpkgs.lib.recursiveUpdate { } [
        (forEachSystem (system: import ./pkgs { pkgs = nixpkgs.legacyPackages.${system}; inherit system getchoo; }))

        # Image Generators
        # (nixpkgs.lib.mapAttrsToList (name: conf: conf.iso) configurations)

        # NixOS Outputs
        # (nixpkgs.lib.mapAttrsToList (name: conf: conf.nixosSystem.config.system.build.toplevel) configurations)
      ] // builtins.mapAttrs (n: v: v.iso) configurations;

      overlays = forEachSystem (system: import ./overlays { pkgs = nixpkgs.legacyPackages.${system}; inherit inputs system outputs getchoo; });

      # Custom Modules
      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;
    };
}
