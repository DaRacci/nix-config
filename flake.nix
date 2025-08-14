{
  description = "The nix-config of an Idiot";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs =
    inputs@{
      self,
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

      mkPkgs =
        {
          system ? "x86_64-linux",
          accelerators ? [ ],
          ...
        }:
        import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
            permittedInsecurePackages = [ ];

            cudaSupport = builtins.elem "cuda" accelerators;
            rocmSupport = builtins.elem "rocm" accelerators;
          };

          overlays = [
            inputs.lix-module.overlays.default
            inputs.angrr.overlays.default
          ]
          ++ (builtins.attrValues (import ./overlays { inherit self inputs lib; }));
        };
    in
    flake-parts.lib.mkFlake
      {
        inherit inputs;
        specialArgs.lib = lib;
      }
      {
        debug = true;
        imports = [
          inputs.devenv.flakeModule
          inputs.treefmt.flakeModule

          ./flake/dev
        ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        flake =
          let
            mkBuilders =
              args:
              import ./lib/builders {
                inherit self inputs lib;
                pkgs = mkPkgs args;
              };

            readDirNoCommons =
              dir:
              builtins.readDir dir
              |> builtins.attrNames
              |> builtins.filter (name: name != "shared")
              |> builtins.filter (name: name != "secrets.yaml");

            accelerationHosts = {
              cuda = [
                "nixmi"
                "winix"
              ];
              rocm = [
                # "nixai"
              ];
            };

            hosts =
              readDirNoCommons ./hosts
              |> builtins.map (deviceType: lib.nameValuePair deviceType (readDirNoCommons ./hosts/${deviceType}))
              |> builtins.listToAttrs;
            hostNames = hosts |> builtins.attrValues |> lib.flatten;

            userHosts =
              readDirNoCommons ./home
              |> builtins.map (
                user:
                lib.nameValuePair user (
                  readDirNoCommons ./home/${user}
                  |> builtins.map (file: lib.removeSuffix ".nix" file)
                  |> builtins.filter (rootFile: builtins.elem rootFile hostNames)
                )
              )
              |> lib.flatten
              |> builtins.listToAttrs;
          in
          {
            nixosConfigurations =
              hosts
              |> lib.mapAttrsToList (
                deviceType: hostNames:
                builtins.map (
                  hostName:
                  lib.nameValuePair hostName {
                    inherit deviceType;
                    users = userHosts |> lib.filterAttrs (_: v: builtins.elem hostName v) |> builtins.attrNames;
                    accelerators =
                      accelerationHosts |> lib.filterAttrs (_: v: builtins.elem hostName v) |> builtins.attrNames;
                  }
                ) hostNames
              )
              |> lib.flatten
              |> builtins.listToAttrs
              |> builtins.mapAttrs (hostName: hostAttrs: (mkBuilders hostAttrs).mkSystem hostName hostAttrs);

            homeConfigurations =
              readDirNoCommons ./home
              |> builtins.map (user: lib.nameValuePair user ((mkBuilders { }).home.mkHomeManager user { }))
              |> builtins.listToAttrs;
          };

        perSystem =
          { pkgs, ... }:
          {
            _module.args.pkgs = mkPkgs { };

            packages = import ./pkgs { inherit inputs pkgs; };
          };
      };

  inputs = {
    # Packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Upstream & PR Programs
    mcpo = {
      url = "https://raw.githubusercontent.com/codgician/nixpkgs/refs/heads/mcpo-init/pkgs/development/python-modules/mcpo/default.nix";
      flake = false;
      type = "file";
    };

    # Misc Flake Inputs for other Inputs
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    # Utils & Helpers for usage inside the flake
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs = {
        nixlib.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
      };
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs = {
        cachix.follows = "";
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nix4vscode = {
      url = "github:nix-community/nix4vscode/nix4vscode-v0.0.8";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    # Windows App Packaging
    erosanix = {
      url = "github:emmanuelrosa/erosanix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    # Base Modules
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        flake-compat.follows = "flake-compat";
        pre-commit-hooks-nix.follows = "git-hooks";
      };
    };
    nixd = {
      url = "github:nix-community/nixd";
      inputs = {
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt";
      };
    };
    nil = {
      url = "github:oxalica/nil/main";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    lix-module = {
      url = "git+https://git.lix.systems/lix-project/nixos-module.git?ref=release-2.93";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        nur.follows = "";
      };
    };
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };
    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    angrr = {
      url = "github:linyinfeng/angrr";
      inputs = {
        treefmt-nix.follows = "treefmt";
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        flake-compat.follows = "flake-compat";
      };
    };
    nixput = {
      url = "github:DaRacci/nixput";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        devenv.follows = "devenv";
        treefmt.follows = "treefmt";
        home-manager.follows = "home-manager";
      };
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Modules only used on some systems
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };
    chaotic-nyx = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    jovian.follows = "chaotic-nyx/jovian";
    nixarr = {
      url = "github:rasmus-kirk/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.website-builder.follows = "";
    };
    crtified-nur = {
      url = "github:CRTified/nur-packages";
      flake = false; # We aren't going to use this as a flake
    };
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.caelestia-cli.follows = "caelestia-cli";
    };
    caelestia-cli = {
      url = "github:caelestia-dots/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop Stuff
    winapps = {
      url = "github:winapps-org/winapps";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
      };
    };
    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Misc Plugins
    bash-env-json = {
      url = "github:tesujimath/bash-env-json";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    bash-env-nushell = {
      url = "github:tesujimath/bash-env-nushell";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        bash-env-json.follows = "bash-env-json";
        flake-utils.follows = "flake-utils";
      };
    };

    # Other misc modules
    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    # Resources
    firefox-ultima = {
      url = "github:soulhotel/FF-ULTIMA/3.0";
      flake = false;
    };
  };
}
