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

    # Desktop Sessions
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = { url = "github:hyprwm/hyprland-plugins"; inputs.hyprland.follows = "hyprland"; };
    anyrun = { url = "github:Kirottu/anyrun"; inputs.nixpkgs.follows = "nixpkgs-unstable"; };

    # Other misc modules
    arion = { url = "github:hercules-ci/arion"; };
    nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; };
    vscode-extensions = { url = "github:nix-community/nix-vscode-extensions"; };

    # DevShell modules
    pre-commit = { url = "github:cachix/pre-commit-hooks.nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    cocogitto = { url = "github:DaRacci/cocogitto"; inputs.nixpkgs.follows = "nixpkgs"; };
    fenix = { url = "github:nix-community/fenix"; inputs.nixpkgs.follows = "nixpkgs"; };
    getchoo = { url = "github:getchoo/nix-exprs"; };
  };

  outputs = { self, nixpkgs, flake-utils, systems, getchoo, nixos-wsl, nixos-generators, ... }@inputs:
    let
      inherit (self) outputs;
      inherit (nixpkgs.lib) listToAttrs foldl' recursiveUpdate;
    in
    foldl' recursiveUpdate { } [
      (flake-utils.lib.eachDefaultSystem (system:
        let
          lib = import ./lib { inherit self inputs system; };
          inherit (lib.shell) mkNix mkRust;
        in
        {
          devShells = listToAttrs [
            (mkNix system "default")
            (mkRust system "rust-stable" { rustChannel = "stable"; })
            (mkRust system "rust-nightly" { rustChannel = "nightly"; })
          ];

          formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
          packages = (import ./pkgs { pkgs = nixpkgs.legacyPackages.${system}; inherit system getchoo; });
          overlays = import ./overlays { pkgs = nixpkgs.legacyPackages.${system}; inherit self inputs system outputs getchoo; };
        }))
      (
        let
          system = "x86_64-linux";
          lib = import ./lib { inherit self inputs system; };

          homeConfigurations = builtins.mapAttrs (n: v: lib.home.mkHm system n v) {
            racci = { };
          };

          configurations = builtins.mapAttrs (n: v: lib.system.build system n v) {
            nixe = {
              users = [ "racci" ];

              isoFormat = "iso";
              deviceType = "desktop";
            };

            surnix = {
              users = [ "racci" ];

              isoFormat = "iso";
              deviceType = "laptop";
            };

            winix = {
              users = [ "racci" ];

              isoFormat = "iso";
              deviceType = "desktop";
            };

            nixcloud = {
              isoFormat = "proxmox-lxc";
              deviceType = "server";
            };
          };
        in
        {
          nixosConfigurations = builtins.mapAttrs (n: v: v.system) configurations;
          homeConfigurations = builtins.mapAttrs (n: v: inputs.home-manager.lib.homeManagerConfiguration v) homeConfigurations;

          packages = {
            # Image Generators
            images = (builtins.mapAttrs (n: v: v.iso) configurations);

            # NixOS Outputs
            outputs = (builtins.mapAttrs (n: v: v.system.config.system.build.toplevel) configurations);
          };

          nixosModules = import ./modules/nixos;
          homeManagerModules = import ./modules/home-manager;
        }
      )
    ];
}
