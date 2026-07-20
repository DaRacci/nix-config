{
  description = ''
    Private inputs for NixOS Systems. These are used by the top level flake in the `nixos` partition.
  '';

  inputs = {
    # Central Inputs for other flakes to follow.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # Base Libraries & Tools
    nixos-hardware.url = "github:nixos/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";

    # Hardware & Boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-overlay.follows = "rust-overlay";
        pre-commit.follows = "";
      };
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "";
      };
    };
    ucodenix.url = "github:e-tho/ucodenix";

    # Services
    angrr = {
      url = "github:linyinfeng/angrr";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        flake-compat.follows = "";
      };
    };
    nixarr = {
      url = "github:rasmus-kirk/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.website-builder.follows = "";
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # System Configurations
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nix-github-actions.follows = "";
      };
    };

    # Misc
    chaotic-nyx = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "";
        flake-schemas.follows = "";
      };
    };
    crtified-nur = {
      url = "github:CRTified/nur-packages";
      flake = false; # We aren't going to use this as a flake
    };
    # TODO - could this also be moved to only being in a partition that just runs from the flake outputs?
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs = {
        nixlib.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
      };
    };
    forgesync = {
      url = "github:lukaswrz/forgesync";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    seaweedfs = {
      url = "https://raw.githubusercontent.com/liberodark/nixpkgs/refs/heads/seawedfs/nixos/modules/services/network-filesystems/seaweedfs.nix";
      flake = false;
      type = "file";
    };
  };

  outputs = _: { };
}
