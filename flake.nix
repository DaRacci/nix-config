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
    deploy-rs = { url = "github:serokell/deploy-rs"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    nixos-generators = { url = "github:nix-community/nixos-generators"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Base Modules
    home-manager = { url = "github:nix-community/home-manager/release-23.11"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware = { url = "github:nixos/nixos-hardware"; };
    nixos-wsl = { url = "github:nix-community/NixOS-WSL"; };
    sops-nix = { url = "github:Mic92/sops-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence = { url = "github:nix-community/impermanence"; };
    nix-colours = { url = "github:misterio77/nix-colors"; };
    lanzaboote = { url = "github:nix-community/lanzaboote/v0.3.0"; inputs.nixpkgs.follows = "nixpkgs"; };
    nix-ld-rs = { url = "github:nix-community/nix-ld-rs"; inputs.nixpkgs.follows = "nixpkgs"; };

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

  outputs = { self, nixpkgs, flake-utils, systems, getchoo, nixos-wsl, nixos-generators, ... }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ];

      inherit (self) outputs;
      inherit (nixpkgs.lib) listToAttrs;
      inherit (import ./lib/mk.nix inputs) mkHomeManagerConfiguration mkConfigurations;
      inherit (import ./lib inputs) mkDevShellNix mkDevShellRust;

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
        (mkDevShellNix system "default")
        (mkDevShellRust system "rust-stable" { rustChannel = "stable"; })
        (mkDevShellRust system "rust-nightly" { rustChannel = "nightly"; })
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
