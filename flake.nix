{
  description = "The nix-config of an Idiot";

  nixConfig = {
    extra-substituters = [
      "https://cache.racci.dev"
      "https://nix-community.cachix.org"
      "https://racci.cachix.org"
      "https://hyprland.cachix.org"
      "https://anyrun.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.racci.dev-1:/i2mJWsMm9rDxIPH3bqNXJXd/wPEDRsJFYiTKh8JPF0="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "racci.cachix.org-1:Kl4opLxvTV9c77DpoKjUOMLDbCv6wy3GVHWxB384gxg="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
    ];
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, systems, ... }:
    let
      lib = inputs.nixpkgs.lib.extend (prev: _: import ./lib { lib = prev; });

      mkPkgs = system: cuda: _rocm: import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
          permittedInsecurePackages = [ ];

          cudaSupport = cuda;
          rocmSupport = false; # FIXME for some reason this is breaking shit when it shouldn't???
        };

        overlays = [
          inputs.hyprland-contrib.overlays.default
        ] ++ (builtins.attrValues (import ./overlays { inherit self inputs lib; }));
      };

      # TODO - Scan the folders for all the configurations and generate the list.
      mkConfigurations = system:
        let
          mkBuilders = cuda: rocm: import ./lib/builders {
            inherit self inputs lib;
            pkgs = mkPkgs system cuda rocm;
          };

          builders = mkBuilders false false;
          buildersWithCuda = mkBuilders true false;
          buildersWithRocm = mkBuilders false true;
        in
        builtins.mapAttrs
          (n: v:
            if (builtins.hasAttr "acceleration" v) then
              if (v.acceleration == "cuda") then buildersWithCuda.system.build system n v
              else if (v.acceleration == "rocm") then buildersWithRocm.system.build system n v
              else builders.system.build system n v
            else builders.system.build system n v
          )
          {
            nixe = {
              users = [ "racci" ];

              isoFormat = "iso";
              deviceType = "desktop";
              acceleration = "cuda";
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
          };
    in
    flake-parts.lib.mkFlake { inherit inputs; specialArgs.lib = lib; } {
      imports = [
        inputs.devenv.flakeModule
      ];

      systems = [ "x86_64-linux" "aarch64-linux" ];

      flake = let configurations = mkConfigurations builtins.currentSystem; in {
        nixosConfigurations = builtins.mapAttrs (_n: v: v.system) configurations;
      };

      perSystem = { system, pkgs, ... }: {
        _module.args.pkgs = mkPkgs system false false;

        packages = import ./pkgs { inherit pkgs; } // (builtins.mapAttrs (_n: v: v.image) (mkConfigurations builtins.currentSystem)) // {
          proxmox-template = pkgs.writeShellApplication {
            name = "copy-template-to-proxmox";
            runtimeInputs = [ pkgs.openssh ];
            text = ''
              TARGET="''${1}"
              if [ -z "$TARGET" ]; then
                echo "No target specified"
                exit 1
              fi

              nix build .#"''${TARGET}" --impure

              echo "Adding result to proxmox templates"
              scp -oIdentitiesOnly=yes result root@192.168.2.210:/var/lib/vz/template/cache/"''${TARGET}"-${pkgs.stdenv.system}.tar.gz
            '';
          };
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

            # Secure Boot Debugging
            sbctl

            # Sops-nix
            age
            sops
            ssh-to-age
          ];

          languages = {
            nix.enable = true;
          };

          pre-commit = {
            hooks = {
              typos = {
                enable = true;
                settings = {
                  diff = true;
                  ignored-words = [
                    "lazer"
                    "Optin"
                    "tere"
                    "ags"
                  ];

                  exclude = "secrets.yaml";
                };
              };
              editorconfig-checker.enable = true;
              actionlint.enable = true;

              nil.enable = true;
              deadnix.enable = true;
              nixpkgs-fmt.enable = true;
              statix.enable = true;
            };
          };

          env = {
            NIX_CONFIG = "extra-experimental-features = nix-command flakes";
          };
        };

        formatter = pkgs.nixpkgs-fmt;
      };
    };

  inputs = {
    # Flake Inputs
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";

    # Packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";

    # Utils
    flake-parts = { url = "github:hercules-ci/flake-parts"; inputs.nixpkgs-lib.follows = "nixpkgs"; };
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    nixos-generators = { url = "github:nix-community/nixos-generators"; inputs = { nixlib.follows = "nixpkgs-lib"; nixpkgs.follows = "nixpkgs"; }; };
    devenv = { url = "github:cachix/devenv"; inputs = { flake-compat.follows = "flake-compat"; }; };

    # Base Modules
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware.url = "github:nixos/nixos-hardware";
    sops-nix = { url = "github:Mic92/sops-nix"; inputs = { nixpkgs.follows = "nixpkgs"; nixpkgs-stable.follows = "nixpkgs"; }; };
    impermanence.url = "github:nix-community/impermanence";
    lanzaboote = { url = "github:nix-community/lanzaboote/v0.3.0"; inputs = { nixpkgs.follows = "nixpkgs"; flake-parts.follows = "flake-parts"; flake-compat.follows = "flake-compat"; }; };
    nixd = { url = "github:nix-community/nixd"; inputs = { nixpkgs.follows = "nixpkgs"; flake-parts.follows = "flake-parts"; }; };
    lix-module = { url = "https://git.lix.systems/lix-project/nixos-module/archive/2.90.0.tar.gz"; inputs.nixpkgs.follows = "nixpkgs"; };
    stylix = { url = "github:danth/stylix"; };
    nix-alien = { url = "github:thiagokokada/nix-alien"; };

    # Modules only used on some systems
    nixos-wsl = { url = "github:nix-community/NixOS-WSL"; inputs = { nixpkgs.follows = "nixpkgs"; flake-compat.follows = "flake-compat"; }; };
    jovian = { url = "github:Jovian-Experiments/Jovian-NixOS"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixarr = { url = "github:rasmus-kirk/nixarr"; };

    # Desktop Stuff
    hyprland = { url = "git+https://github.com/hyprwm/Hyprland?submodules=1"; };
    hyprland-plugins = { url = "github:hyprwm/hyprland-plugins"; inputs.hyprland.follows = "hyprland"; };
    hyprland-contrib.url = "github:hyprwm/contrib";
    anyrun = { url = "github:anyrun-org/anyrun"; inputs = { nixpkgs.follows = "nixpkgs"; flake-parts.follows = "flake-parts"; }; };
    astal = { url = "github:aylur/astal"; inputs.nixpkgs.follows = "nixpkgs"; };
    ags = { url = "github:aylur/ags/v2"; inputs = { nixpkgs.follows = "nixpkgs"; astal.follows = "astal"; }; };

    # Other misc modules
    arion = { url = "github:hercules-ci/arion"; };
    vscode-extensions = { url = "github:nix-community/nix-vscode-extensions"; inputs = { nixpkgs.follows = "nixpkgs"; flake-compat.follows = "flake-compat"; }; };
    moza-racing = { url = "github:danerieber/moza-racing-wheel-nix"; };

    # Resources
    firefox-ultima = { url = "github:soulhotel/FF-ULTIMA"; flake = false; };
    tinted-theming = { url = "github:tinted-theming/schemes"; flake = false; };
  };
}
