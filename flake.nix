{
  description = "The nix-config of an Idiot";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://anyrun.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
    ];
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      systems,
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
        system: cuda: _rocm:
        import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
            permittedInsecurePackages = [
              "aspnetcore-runtime-6.0.36"
              "dotnet-sdk-6.0.428"
              "dotnet-sdk-7.0.410"
              "dotnet-runtime-7.0.20"
            ];

            cudaSupport = cuda;
            rocmSupport = false; # FIXME for some reason this is breaking shit when it shouldn't???
          };

          overlays = [
            inputs.hyprland-contrib.overlays.default
            inputs.lix-module.overlays.lixFromNixpkgs
            inputs.angrr.overlays.default
            inputs.hyprpanel.overlay
          ] ++ (builtins.attrValues (import ./overlays { inherit self inputs lib; }));
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
        ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        flake =
          let
            system = builtins.currentSystem;
            mkBuilders =
              cuda: rocm:
              import ./lib/builders {
                inherit inputs lib;
                flake = self;
                pkgs = mkPkgs system cuda rocm;
              };

            builders = mkBuilders false false;
            buildersWithCuda = mkBuilders true false;
            buildersWithRocm = mkBuilders false true;
            # TODO - Scan the folders for all the configurations and generate the list.
            configurations =
              builtins.mapAttrs
                (
                  n: v:
                  if (builtins.hasAttr "acceleration" v) then
                    if (v.acceleration == "cuda") then
                      buildersWithCuda.system.build system n v
                    else if (v.acceleration == "rocm") then
                      buildersWithRocm.system.build system n v
                    else
                      builders.system.build system n v
                  else
                    builders.system.build system n v
                )
                {
                  nixe = {
                    users = [ "racci" ];

                    isoFormat = "iso";
                    deviceType = "desktop";
                    acceleration = "cuda";
                  };

                  winix = {
                    users = [ "racci" ];

                    isoFormat = "iso";
                    deviceType = "desktop";
                    acceleration = "cuda";
                  };

                  nixarr = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                    acceleration = "rocm";
                  };

                  nixcloud = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                    acceleration = "rocm";
                  };

                  nixdev = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                    acceleration = "rocm";
                  };

                  nixio = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                    acceleration = "rocm";
                  };

                  nixmon = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                    acceleration = "rocm";
                  };

                  nixserv = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                    acceleration = "rocm";
                  };

                  nixai = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                    acceleration = "rocm";
                  };

                  #|----------------------|
                  #|  Deprecated Systems  |
                  #|----------------------|
                  # surnix = {
                  #   users = [ "racci" ];

                  #   isoFormat = "iso";
                  #   deviceType = "laptop";
                  # };
                };

            users = lib.genAttrs [ "racci" ] (name: builders.home.mkHomeManager system name { });
          in
          {
            nixosConfigurations = builtins.mapAttrs (_n: v: v.system) configurations;

            homeConfigurations = users;
          };

        perSystem =
          { system, pkgs, ... }:
          rec {
            _module.args.pkgs = mkPkgs system false false;

            packages = import ./pkgs { inherit pkgs; };

            treefmt = {
              projectRootFile = ".git/config";

              programs = {
                actionlint.enable = true;
                deadnix.enable = true;
                nixfmt.enable = true;
                shellcheck.enable = true;
                statix.enable = true;
                mdformat.enable = true;
                mdsh.enable = true;
              };

              settings.formatter.shellcheck.excludes = [ ".envrc" ];
              settings.global.excludes = [
                "**/secrets.yaml"
                "**/ssh_host_ed25519_key.pub"
                "modules/home-manager/purpose/development/editors/vscode/extensions.nix"
              ];
            };

            devenv.shells.default = {
              # Fixes https://github.com/cachix/devenv/issues/528
              containers = lib.mkForce { };

              packages = with pkgs; [
                # Cli Tools
                act # Github Action testing
                hyperfine # Benchmarking
                cocogitto # Conventional Commits

                # Required Tools
                nix
                git
                home-manager

                # Converting to Nix
                dconf2nix

                # Secure Boot Debugging
                sbctl

                # Sops-nix
                age
                sops
                ssh-to-age
              ];

              languages = {
                nix.enable = false;
              };

              env = {
                NIX_CONFIG = "extra-experimental-features = nix-command flakes";
              };

              git-hooks = {
                excludes = [
                  "modules/home-manager/purpose/development/editors/vscode/extensions.nix"
                ];

                hooks = {
                  nil.enable = true;
                  actionlint.enable = true;
                  deadnix.enable = true;
                  nixfmt-rfc-style.enable = true;
                  statix = {
                    enable = true;
                    settings.ignore = treefmt.settings.global.excludes;
                  };
                };
              };
            };
          };
      };

  inputs = {
    # Packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Utils
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
    crane.url = "github:ipetkov/crane/f2926e34a1599837f3256c701739529d772e36e7";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        flake-compat.follows = "flake-compat";
        crane.follows = "crane";
      };
    };
    nixd = {
      url = "github:nix-community/nixd";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/stable.tar.gz";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        lix.follows = "";
      };
    };
    stylix.url = "github:danth/stylix";
    nix-alien.url = "github:thiagokokada/nix-alien";
    treefmt.url = "github:numtide/treefmt-nix";
    angrr.url = "github:linyinfeng/angrr";
    nixput = {
      # url = "github:DaRacci/nixput";
      url = "git+file:///home/racci/Projects/nix/nixput";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        devenv.follows = "devenv";
        treefmt.follows = "treefmt";
      };
    };

    # Modules only used on some systems
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixarr.url = "github:rasmus-kirk/nixarr";

    # Desktop Stuff
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    hyprland-contrib.url = "github:hyprwm/contrib";
    hyprland-dynamic-cursors = {
      url = "github:VirtCode/hypr-dynamic-cursors";
      inputs.hyprland.follows = "hyprland";
    };
    hy3 = {
      url = "github:outfoxxed/hy3";
      inputs.hyprland.follows = "hyprland";
    };
    hyprpanel.url = "github:Jas-SinghFSU/HyprPanel";
    anyrun = {
      url = "github:anyrun-org/anyrun";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };

    # Misc Plugins
    nu-bash-env = {
      url = "github:tesujimath/bash-env-nushell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Other misc modules
    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    # Resources
    firefox-ultima = {
      url = "github:soulhotel/FF-ULTIMA/1.9.8.5";
      flake = false;
    };
    tinted-theming = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };

    # Packages from PRs
    protonup-rs.url = "github:liperium/nixpkgs/protonuprs-init";
    lact-module.url = "github:poperigby/nixpkgs/lact-module";
    lact.url = "github:cything/nixpkgs/lact";
  };
}
