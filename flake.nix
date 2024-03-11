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
    # Flake Inputs
    crane.url = "github:ipetkov/crane";
    fenix.url = "github:nix-community/fenix";
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
    rust-overlay.url = "github:oxalica/rust-overlay";

    # Packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";

    # Utils
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    nixos-generators.url = "github:nix-community/nixos-generators";

    # Base Modules
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    sops-nix.url = "github:Mic92/sops-nix";
    impermanence.url = "github:nix-community/impermanence";
    nix-ld-rs.url = "github:nix-community/nix-ld-rs";
    lanzaboote.url = "github:nix-community/lanzaboote/v0.3.0";

    # Modules only used on some systems
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    attic.url = "github:zhaofengli/attic";

    # Desktop Sessions
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    anyrun.url = "github:Kirottu/anyrun";

    # Other misc modules
    # arion = { url = "github:hercules-ci/arion"; };
    # nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; };
    vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    # DevShell modules
    pre-commit-hooks-nix.url = "github:cachix/pre-commit-hooks.nix";
    cocogitto.url = "github:DaRacci/cocogitto";

    #region Flake input following
    nixos-generators.inputs.nixlib.follows = "nixpkgs-lib";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs-unstable";

    rust-overlay.inputs.nixpkgs.follows = "nixpkgs-unstable";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";

    pre-commit-hooks-nix.inputs.nixpkgs-stable.follows = "nixpkgs";
    pre-commit-hooks-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    pre-commit-hooks-nix.inputs.flake-compat.follows = "flake-compat";
    pre-commit-hooks-nix.inputs.flake-utils.follows = "flake-utils";

    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    fenix.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-unstable";

    hyprland.inputs.nixpkgs.follows = "nixpkgs-unstable";

    sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";

    attic.inputs.nixpkgs-stable.follows = "nixpkgs";
    attic.inputs.nixpkgs.follows = "nixpkgs-unstable";
    attic.inputs.flake-utils.follows = "flake-utils";
    attic.inputs.flake-compat.follows = "flake-compat";
    attic.inputs.crane.follows = "crane";

    anyrun.inputs.nixpkgs.follows = "nixpkgs-unstable";
    anyrun.inputs.flake-parts.follows = "flake-parts";

    nix-ld-rs.inputs.nixpkgs.follows = "nixpkgs-unstable";
    nix-ld-rs.inputs.flake-utils.follows = "flake-utils";
    nix-ld-rs.inputs.flake-compat.follows = "flake-compat";

    vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    vscode-extensions.inputs.flake-utils.follows = "flake-utils";
    vscode-extensions.inputs.flake-compat.follows = "flake-compat";

    lanzaboote.inputs.nixpkgs.follows = "nixpkgs-unstable";
    lanzaboote.inputs.flake-parts.follows = "flake-parts";
    lanzaboote.inputs.flake-utils.follows = "flake-utils";
    lanzaboote.inputs.flake-compat.follows = "flake-compat";
    lanzaboote.inputs.crane.follows = "crane";
    lanzaboote.inputs.rust-overlay.follows = "rust-overlay";
    lanzaboote.inputs.pre-commit-hooks-nix.follows = "pre-commit-hooks-nix";

    cocogitto.inputs.flake-utils.follows = "flake-utils";
    cocogitto.inputs.nixpkgs.follows = "nixpkgs";
    cocogitto.inputs.crane.follows = "crane";
    cocogitto.inputs.fenix.follows = "fenix";
    cocogitto.inputs.systems.follows = "systems";

    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl.inputs.flake-utils.follows = "flake-utils";
    nixos-wsl.inputs.flake-compat.follows = "flake-compat";

    #endregion
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

          # TODO - Scan the folders for all the configurations and generate the list.
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

            nixserv = {
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
