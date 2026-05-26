{
  description = "The nix-config of an Idiot";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://cache.nixos-cuda.org"
      "https://cache.racci.dev/global"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "global:OKNSxDYKp8Q8Tr5/5Bc7CYVSfvdFQV0dMhpG0fOAG0k="
    ];
  };

  outputs =
    inputs@{
      flake-parts,
      ...
    }:
    let
      lib = inputs.nixpkgs.lib.extend (
        prev: _:
        import ./lib {
          inherit inputs;
          lib = prev;
        }
      );
    in
    flake-parts.lib.mkFlake
      {
        inherit inputs;
        specialArgs.lib = lib;
      }
      {
        debug = true;
        imports = [ ./flake ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
      };

  inputs = {
    # Packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    #TODO:https://github.com/nlewo/nix2container/issues/186
    nix2container.url = "github:nlewo/nix2container?rev=e5496ab66e9de9e3f67dc06f692dfbc471b6316e";
    lix = {
      url = "git+https://git.lix.systems/lix-project/lix.git?ref=release-2.94";
      flake = false;
    };

    # Upstream & PR Programs
    #TODO:https://github.com/NixOS/nixpkgs/pull/410836
    mcpo = {
      url = "https://raw.githubusercontent.com/codgician/nixpkgs/refs/heads/mcpo-init/pkgs/development/python-modules/mcpo/default.nix";
      flake = false;
      type = "file";
    };
    #TODO:https://github.com/NixOS/nixpkgs/pull/485360
    tabby = {
      url = "https://raw.githubusercontent.com/dillonfrederica/nixpkgs/refs/heads/tabby-0.32.0/pkgs/by-name/ta/tabby/package.nix";
      flake = false;
      type = "file";
    };
    #TODO:https://github.com/NixOS/nixpkgs/pull/484702
    tabby-agent = {
      url = "https://raw.githubusercontent.com/r-ryantm/nixpkgs/refs/heads/auto-update/tabby-agent/pkgs/by-name/ta/tabby-agent/package.nix";
      flake = false;
      type = "file";
    };

    # Misc Flake Inputs for other Inputs
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    # Utils & Helpers for usage inside the flake
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };

    # Windows App Packaging
    erosanix = {
      url = "github:emmanuelrosa/erosanix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "";
      };
    };
  };
}
