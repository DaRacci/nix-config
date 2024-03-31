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
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";

    # Packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";

    # Utils
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    flake-compat-nixd = { url = "github:inclyc/flake-compat"; flake = false; };
    nixos-generators.url = "github:nix-community/nixos-generators";

    # Base Modules
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    sops-nix.url = "github:Mic92/sops-nix";
    impermanence.url = "github:nix-community/impermanence";
    nix-ld-rs.url = "github:nix-community/nix-ld-rs";
    lanzaboote.url = "github:nix-community/lanzaboote/v0.3.0";
    nixd.url = "github:nix-community/nixd";
    nix-colours.url = "github:misterio77/nix-colors";

    # Modules only used on some systems
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    attic.url = "github:zhaofengli/attic";

    # Desktop Sessions
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-contrib.url = "github:hyprwm/contrib";
    anyrun.url = "github:Kirottu/anyrun";
    haumea = { url = "github:nix-community/haumea/v0.2.2"; inputs.nixpkgs.follows = "nixpkgs"; };

    # Other misc modules
    # arion = { url = "github:hercules-ci/arion"; };
    # nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; };
    vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    #region Flake input following
    nixos-generators.inputs.nixlib.follows = "nixpkgs-lib";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs-unstable";

    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-unstable";

    hyprland.inputs.nixpkgs.follows = "nixpkgs-unstable";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";

    sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";

    attic.inputs.nixpkgs-stable.follows = "nixpkgs";
    attic.inputs.nixpkgs.follows = "nixpkgs-unstable";
    attic.inputs.flake-utils.follows = "flake-utils";
    attic.inputs.flake-compat.follows = "flake-compat";
    # attic.inputs.crane.follows = "crane";

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
    # lanzaboote.inputs.crane.follows = "crane";
    # lanzaboote.inputs.rust-overlay.follows = "rust-overlay";
    # lanzaboote.inputs.pre-commit-hooks-nix.follows = "pre-commit-hooks-nix";

    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    nixos-wsl.inputs.flake-utils.follows = "flake-utils";
    nixos-wsl.inputs.flake-compat.follows = "flake-compat";

    nixd.inputs.nixpkgs.follows = "nixpkgs-unstable";
    nixd.inputs.flake-parts.follows = "flake-parts";
    #endregion
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, systems, nixos-wsl, nixos-generators, haumea, ... }:
    let
      inherit (self) outputs;
      inherit (nixpkgs.lib) listToAttrs foldl' recursiveUpdate;

      lib = inputs.nixpkgs.lib.extend (prev: _: import ./lib { lib = prev; });
      haumea = haumea.lib.load { src = ./.; inputs = { inherit lib; }; };
      builders = import ./lib/builders { inherit self inputs lib haumea; };

      # TODO - Scan the folders for all the configurations and generate the list.
      configurations = builtins.mapAttrs (n: v: builders.system.build builtins.currentSystem n v) {
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
    in flake-parts.lib.mkFlake { inherit inputs; specialArgs.lib = lib; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];      

      flake = rec {
        nixosConfigurations = builtins.mapAttrs (n: v: v.system) configurations;

        nixosModules = import ./modules/nixos;
        homeManagerModules = import ./modules/home-manager;

        packages = {
          # Image Generators
          images = (builtins.mapAttrs (n: v: v.iso) configurations);

          # NixOS Outputs
          outputs = (builtins.mapAttrs (n: v: v.config.system.build.toplevel) nixosConfigurations);
        };
      };

      perSystem = { config, system, lib, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowUnfreePredicate = (_: true);
            permittedInsecurePackages = [ ];
          };

          overlays = [
            inputs.hyprland-contrib.overlays.default
          ] ++ builtins.attrValues import ./overlays;
        };

        packages = {
          # Image Generators
          # images = (builtins.mapAttrs (n: v: v.iso) configurations);

          # NixOS Outputs
          # outputs = (builtins.mapAttrs (n: v: v.system.config.system.build.toplevel) config.nixosConfigurations);
        } // (import ./pkgs { pkgs = nixpkgs.legacyPackages.${system}; inherit system; });

        devShells = listToAttrs [
          (lib.shell.mkNix system "default")
        ];

        formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
        # overlays = import ./overlays { pkgs = nixpkgs.legacyPackages.${system}; inherit self inputs system outputs; };
      };
    };
}
