{
  description = "The nix-config of an Idiot";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://racci.cachix.org"
      "https://hyprland.cachix.org"
      "https://anyrun.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "racci.cachix.org-1:Kl4opLxvTV9c77DpoKjUOMLDbCv6wy3GVHWxB384gxg="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
    ];
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, systems, ... }:
    let
      lib = inputs.nixpkgs.lib.extend (prev: _: import ./lib { lib = prev; });

      mkPkgs = system: import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
          permittedInsecurePackages = [ ];
        };

        overlays = [
          inputs.hyprland-contrib.overlays.default
        ] ++ (builtins.attrValues (import ./overlays { inherit self inputs lib; }));
      };

      # TODO - Scan the folders for all the configurations and generate the list.
      mkConfigurations = system:
        let
          builders = import ./lib/builders {
            inherit self inputs lib;
            pkgs = mkPkgs system;
          };
        in
        builtins.mapAttrs (n: v: builders.system.build system n v) {
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

          nixdev = {
            isoFormat = "proxmox-lxc";
            deviceType = "server";
          };

          nixio = {
            isoFormat = "proxmox-lxc";
            deviceType = "server";
          };

          nixserv = {
            isoFormat = "proxmox-lxc";
            deviceType = "server";
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
        packages = {
          # Image Generators
          images = builtins.mapAttrs (_n: v: v.image) configurations;

          # NixOS Outputs
          outputs = builtins.mapAttrs (_n: v: v.system.config.system.build.toplevel) configurations;
        };
      };

      perSystem = { system, pkgs, ... }: {
        _module.args.pkgs = mkPkgs system;

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
            NIX_CONFIG = "extra-experimental-features = nix-command flakes repl-flake";
          };
        };

        formatter = pkgs.nixpkgs-fmt;
      };
    };

  inputs = {
    # Flake Inputs
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";

    # Packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nur.url = "github:nix-community/NUR";

    # Utils
    flake-parts = { url = "github:hercules-ci/flake-parts"; inputs.nixpkgs-lib.follows = "nixpkgs-unstable"; };
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    flake-compat-nixd = { url = "github:inclyc/flake-compat"; flake = false; };
    nixos-generators = { url = "github:nix-community/nixos-generators"; inputs = { nixlib.follows = "nixpkgs-lib"; nixpkgs.follows = "nixpkgs-unstable"; }; };
    devenv.url = "github:cachix/devenv";

    # Base Modules
    home-manager = { url = "github:nix-community/home-manager/release-24.05"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixos-hardware.url = "github:nixos/nixos-hardware";
    sops-nix = { url = "github:Mic92/sops-nix"; inputs = { nixpkgs.follows = "nixpkgs-unstable"; nixpkgs-stable.follows = "nixpkgs"; }; };
    impermanence.url = "github:nix-community/impermanence";
    nix-ld-rs = { url = "github:nix-community/nix-ld-rs"; inputs = { nixpkgs.follows = "nixpkgs-unstable"; flake-compat.follows = "flake-compat"; }; };
    lanzaboote = { url = "github:nix-community/lanzaboote/v0.3.0"; inputs = { nixpkgs.follows = "nixpkgs-unstable"; flake-parts.follows = "flake-parts"; flake-compat.follows = "flake-compat"; }; };
    nixd = { url = "github:nix-community/nixd"; inputs = { nixpkgs.follows = "nixpkgs-unstable"; flake-parts.follows = "flake-parts"; }; };
    nix-colours.url = "github:misterio77/nix-colors";

    # Modules only used on some systems
    nixos-wsl = { url = "github:nix-community/NixOS-WSL"; inputs = { nixpkgs.follows = "nixpkgs"; flake-compat.follows = "flake-compat"; }; };
    attic = { url = "github:zhaofengli/attic"; inputs = { nixpkgs-stable.follows = "nixpkgs"; nixpkgs.follows = "nixpkgs-unstable"; flake-compat.follows = "flake-compat"; }; };
    jovian = { url = "github:Jovian-Experiments/Jovian-NixOS"; inputs.nixpkgs.follows = "nixpkgs-unstable"; };

    # Hyprland Stuff
    hyprland = { url = "git+https://github.com/hyprwm/Hyprland?submodules=1"; inputs.nixpkgs.follows = "nixpkgs-unstable"; };
    hyprland-plugins = { url = "github:hyprwm/hyprland-plugins"; inputs.hyprland.follows = "hyprland"; };
    hyprland-contrib.url = "github:hyprwm/contrib";
    hy3 = { url = "github:outfoxxed/hy3"; inputs.hyprland.follows = "hyprland"; };
    ags.url = "github:Aylur/ags";
    asztal = {
      url = "github:Aylur/dotfiles";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        home-manager.follows = "home-manager";
        ags.follows = "ags";
        hyprland.follows = "hyprland";
        hyprland-plugins.follows = "hyprland-plugins";
        firefox-gnome-theme.follows = "firefox-gnome-theme";
      };
    };
    anyrun = { url = "github:peppidesu/anyrun/hyprland-socket-move-fix"; inputs = { nixpkgs.follows = "nixpkgs-unstable"; flake-parts.follows = "flake-parts"; }; };

    # Other misc modules
    arion = { url = "github:hercules-ci/arion"; };
    # nix-doom-emacs = { url = "github:nix-community/nix-doom-emacs"; };
    vscode-extensions = { url = "github:nix-community/nix-vscode-extensions"; inputs = { nixpkgs.follows = "nixpkgs"; flake-compat.follows = "flake-compat"; }; };
    firefox-gnome-theme = { url = "github:rafaelmardojai/firefox-gnome-theme"; flake = false; };
  };
}
