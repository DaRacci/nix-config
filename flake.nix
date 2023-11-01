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
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };

    # Base Modules
    home-manager = { url = "github:nix-community/home-manager/release-23.05"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware = { url = "github:nixos/nixos-hardware"; };
    nixos-wsl = { url = "github:nix-community/NixOS-WSL"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence = { url = "github:nix-community/impermanence"; };
    nix-colours = { url = "github:misterio77/nix-colors"; };
    lanzaboote = { url = "github:nix-community/lanzaboote/v0.3.0"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Containers & Stuff
    arion = { url = "github:hercules-ci/arion"; };

    # Optional Modules
    # hyprland = { url = "github:hyprwm/Hyprland"; };
    # hyprland-plugins = { url = "github:hyprwm/hyprland-plugins"; };
    nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; };
    fenix = { url = "github:nix-community/fenix"; inputs.nixpkgs.follows = "nixpkgs"; };
    getchoo = { url = "github:getchoo/nix-exprs"; };
    # emacs-overlay = { url = "github:nix-community/emacs-overlay"; };
    # xremap-flake.url = "github:xremap/nix-flake";

    # Cosmic Desktop
    # cosmic-applets.url = "github:pop-os/cosmic-applets";
    # cosmic-applibrary.url = "github:pop-os/cosmic-applibrary";
    # cosmic-bg.url = "github:pop-os/cosmic-bg";
    # cosmic-comp.url = "github:pop-os/cosmic-comp";
    # cosmic-launcher.url = "github:pop-os/cosmic-launcher";
    # cosmic-notifications.url = "github:pop-os/cosmic-notifications";
    # cosmic-osd.url = "github:pop-os/cosmic-osd";
    # cosmic-panel.url = "github:pop-os/cosmic-panel";
    # cosmic-session.url = "github:pop-os/cosmic-session";
    # cosmic-settings.url = "github:pop-os/cosmic-settings";
    # cosmic-settings-daemon.url = "github:pop-os/cosmic-settings-daemon";
    # cosmic-workspaces.url = "github:pop-os/cosmic-workspaces-epoch";
    # cosmic-portal.url = "github:pop-os/xdg-desktop-portal-cosmic";
  };

  outputs = { self, nixpkgs, flake-utils, systems, getchoo, nixos-wsl, ... }@inputs:
    let
      inherit (self) outputs;
      inherit (import ./lib/mk.nix inputs) mkSystem mkHome;
    in
    {
      nixosConfigurations = builtins.mapAttrs mkSystem {
        nixe = {
          persistenceType = "tmpfs";
          users = [ "racci" ];
        };
        surnix = {
          persistenceType = "btrfs";
          users = [ "racci" ];
        };
        winix = {
          users = [ "racci" ];
        };
      };

      homeConfigurations = builtins.mapAttrs mkHome {
        racci = { host = "nixe"; };
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = import ./pkgs { inherit pkgs getchoo; };
        devShells = import ./shell.nix { inherit pkgs; };
        formatter = pkgs.nixpkgs-fmt;
      }) // {
      overlays = import ./overlays { inherit inputs outputs getchoo; };

      nixosModules = import ./modules/nixos;

      homeManagerModules = import ./modules/home-manager;
    };
}
