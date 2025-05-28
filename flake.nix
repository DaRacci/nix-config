{
  description = "The nix-config of an Idiot";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
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
        system: cuda: rocm:
        import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
            permittedInsecurePackages = [ ];

            cudaSupport = cuda;
            rocmSupport = rocm;
          };

          overlays = [
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
            buildersWithRocm = mkBuilders false false;
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
                  nixmi = {
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
                  };

                  nixcloud = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                  };

                  nixdev = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                  };

                  nixio = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                  };

                  nixmon = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                  };

                  nixserv = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                  };

                  nixai = {
                    isoFormat = "proxmox-lxc";
                    deviceType = "server";
                  };
                };

            users = lib.genAttrs [ "racci" "root" ] (name: builders.home.mkHomeManager system name { });
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

                # Nix tools
                nvd
                nix-tree
                nil
                nixd
                nixfmt-rfc-style

                # Required Tools
                nix
                git
                home-manager
                inputs.nix4vscode.packages.${system}.nix4vscode

                # Converting to Nix
                dconf2nix

                # Install & Setup Tools
                sbctl
                disko
                cryptsetup

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

              scripts = {
                update-vscode.exec = ''
                  DIR="modules/home-manager/purpose/development/editors/vscode"
                  CONFIG="$DIR/config.toml"
                  NIX_FILE="$DIR/extensions.nix"
                  VSCODE_VERSION=${pkgs.vscode.version}

                  sed -i "s/vscode_version = \".*\"/vscode_version = \"$VSCODE_VERSION\"/" "$CONFIG"
                  nix4vscode "$CONFIG" -o "$NIX_FILE"
                '';
                dump-vscode.exec = ''
                  echo 'vscode_version = "'${pkgs.vscode.version}'"'
                  echo
                  echo 'extensions = ['
                  (code --list-extensions 2>/dev/null) | while read extension; do
                    publisher_name=$(echo "$extension" | cut -d '.' -f 1)
                    extension_name=$(echo "$extension" | cut -d '.' -f 2-)
                    echo "  \"$publisher_name.$extension_name\""
                  done
                  echo ']'
                  echo
                '';
              };

              git-hooks = {
                excludes = [
                  "modules/home-manager/purpose/development/editors/vscode/extensions.nix"
                ];

                hooks = {
                  check-added-large-files.enable = true;
                  check-case-conflicts.enable = true;
                  check-executables-have-shebangs.enable = true;
                  check-shebang-scripts-are-executable.enable = true;
                  check-merge-conflicts.enable = true;
                  detect-private-keys.enable = true;
                  fix-byte-order-marker.enable = true;
                  mixed-line-endings.enable = true;
                  trim-trailing-whitespace.enable = true;

                  nil.enable = true;
                  actionlint.enable = true;
                  deadnix.enable = true;
                  nixfmt-rfc-style.enable = true;
                  shellcheck.enable = true;
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

    # Upstream & PR Programs
    lan-mouse = {
      url = "github:feschber/lan-mouse";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vigiland = {
      url = "github:jappie3/vigiland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    protonup-rs.url = "github:liperium/nixpkgs/protonuprs-init";
    lact-module.url = "github:poperigby/nixpkgs/lact-module";
    lact.url = "github:cything/nixpkgs/lact";
    flaresolverr.url = "github:paveloom/nixpkgs/flaresolverr";
    stl-thumb.url = "github:SyntaxualSugar/stl-thumb_0.5.0";

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
        pre-commit-hooks-nix.follows = "";
      };
    };
    nixd = {
      url = "github:nix-community/nixd";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt";
      };
    };
    lix-module = {
      url = "git+https://git.lix.systems/lix-project/nixos-module.git?ref=stable";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        lix.follows = "";
      };
    };
    stylix = {
      url = "github:danth/stylix";
      inputs = {
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
        git-hooks.follows = "";
        home-manager.follows = "home-manager";
        nur.follows = "nur";
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
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixarr = {
      url = "github:rasmus-kirk/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.website-builder.follows = "";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt";
      };
    };

    # Desktop Stuff
    hyprpanel = {
      url = "github:Jas-SinghFSU/HyprPanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      url = "github:soulhotel/FF-ULTIMA/1.9.9";
      flake = false;
    };
    tinted-theming = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };
    stylix-wallpaper = {
      url = "https://nextcloud.racci.dev/s/Hy8qkAWYwqSTjKp/download/17.jpeg";
      flake = false;
      type = "file";
    };
  };
}
