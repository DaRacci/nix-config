{
  description = "The nix-config of an Idiot";

  inputs = {
    # Packages
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-23.05"; };
    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nur = { url = "github:nix-community/NUR"; };

    # Utils
    systems = { url = "github:nix-systems/current-system"; };
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
    # inputs.xremap-flake.url = "github:xremap/nix-flake";
    # rust-overlay.url = "github:oxalica/rust-overlay";
    # xremap-flake.url = "github:xremap/nix-flake";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      forEachPkgs = fn: flake-utils.lib.eachDefaultSystem (system: fn nixpkgs.legacyPackages.${system});

      inherit (self) outputs;
      inherit (import ./lib/attrsets.nix { inherit (nixpkgs) lib; }) recursiveMergeAttrs;
      inherit (import ./lib/mk.nix inputs) mkNixosConfig mkHomeConfig;
    in
    (recursiveMergeAttrs [
      (mkNixosConfig { hostname = "nixe"; })
      (mkNixosConfig { hostname = "surnix"; })

      (mkHomeConfig { username = "racci"; hostname = "nixe"; })
      (mkHomeConfig { username = "racci"; hostname = "surnix"; })
    ]) // {
      # Custom packages; Acessible through 'nix build', 'nix shell', etc
      packages = forEachPkgs (pkgs: (import ./pkgs { inherit pkgs; }));

      # Devshell for bootstrapping; Acessible through 'nix develop' or 'nix-shell' (legacy)
      devShells = forEachPkgs (pkgs: (import ./shell.nix { inherit pkgs; }));

      formatter = forEachPkgs (pkgs: pkgs.nixpkgs-fmt); #?? TF is this?

      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs outputs; };

      nixosModules = import ./modules/nixos;

      homeManagerModules = import ./modules/home-manager;
    };
}
