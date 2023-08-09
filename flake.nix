{
  description = "The nix-config of an Idiot";

  nixConfig = {
    extra-substituters = [ "https://racci.cachix.org" ];
    extra-trusted-public-keys = [ "racci.cachix.org-1:Kl4opLxvTV9c77DpoKjUOMLDbCv6wy3GVHWxB384gxg=" ];
  };

  inputs = {
    # Packages
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-23.05"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nur = { url = "github:nix-community/NUR"; };

    # Utils
    systems = { url = "github:nix-systems/X86_64-linux"; }; # TODO - Add Darwin
    flake-utils = { url = "github:numtide/flake-utils"; inputs.systems.follows = "systems"; };

    # Base Modules
    home-manager = { url = "github:nix-community/home-manager/release-23.05"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware = { url = "github:nixos/nixos-hardware"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence = { url = "github:nix-community/impermanence"; };
    nix-colours = { url = "github:misterio77/nix-colors"; };

    # Containers & Stuff
    arion = { url = "github:hercules-ci/arion"; };

    # Optional Modules
    hyprland = { url = "github:hyprwm/Hyprland"; };
    nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; };
    fenix = { url = "github:nix-community/fenix"; inputs.nixpkgs.follows = "nixpkgs"; };
    # emacs-overlay = { url = "github:nix-community/emacs-overlay"; };
    # xremap-flake.url = "github:xremap/nix-flake";
  };

  outputs = { self, nixpkgs, flake-utils, systems, ... }@inputs:
    let
      inherit (self) outputs;
      inherit (import ./lib/mk.nix inputs) mkSystem mkHome;
    in
    {
      nixosConfigurations = builtins.mapAttrs mkSystem {
        nixe = { users = [ "racci" ]; };
        # surnix = { };
      };

      homeConfigurations = builtins.mapAttrs mkHome {
        racci = { host = "nixe"; };
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = import ./pkgs { inherit pkgs; };
        devShells = import ./shell.nix { inherit pkgs; };
        formatter = pkgs.nixpkgs-fmt;
      }) // {
      overlays = import ./overlays { inherit inputs outputs; };

      nixosModules = import ./modules/nixos;

      homeManagerModules = import ./modules/home-manager;
    };
}
